const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { Pool } = require("pg");
const redis = require("redis");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const winston = require("winston");
const { register, collectDefaultMetrics } = require("prom-client");

// Initialize logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: "user-service" },
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: "error.log", level: "error" }),
    new winston.transports.File({ filename: "combined.log" }),
  ],
});

// Initialize Prometheus metrics
collectDefaultMetrics();
const httpRequestDurationMicroseconds = new register.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.1, 0.5, 1, 2, 5],
});

const httpRequestsTotal = new register.Counter({
  name: "http_requests_total",
  help: "Total number of HTTP requests",
  labelNames: ["method", "route", "status_code"],
});

// Initialize database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl:
    process.env.NODE_ENV === "production"
      ? { rejectUnauthorized: false }
      : false,
});

// Initialize Redis connection
const redisClient = redis.createClient({
  url: process.env.REDIS_URL,
});

redisClient.on("error", (err) => logger.error("Redis Client Error", err));
redisClient.on("connect", () => logger.info("Connected to Redis"));

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: "Too many requests from this IP, please try again later.",
});
app.use(limiter);

// Metrics middleware
app.use((req, res, next) => {
  const start = Date.now();
  res.on("finish", () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDurationMicroseconds
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .inc();
  });
  next();
});

// Health check endpoint
app.get("/health", async (req, res) => {
  try {
    // Check database connection
    await pool.query("SELECT 1");

    // Check Redis connection
    await redisClient.ping();

    res.status(200).json({
      status: "healthy",
      service: "user-service",
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  } catch (error) {
    logger.error("Health check failed", error);
    res.status(503).json({
      status: "unhealthy",
      service: "user-service",
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Metrics endpoint
app.get("/metrics", async (req, res) => {
  try {
    res.set("Content-Type", register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    logger.error("Metrics endpoint error", error);
    res.status(500).end();
  }
});

// User routes
app.post("/api/v1/users/register", async (req, res) => {
  try {
    const { email, password, name } = req.body;

    // Validate input
    if (!email || !password || !name) {
      return res
        .status(400)
        .json({ error: "Email, password, and name are required" });
    }

    // Check if user already exists
    const existingUser = await pool.query(
      "SELECT id FROM users WHERE email = $1",
      [email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({ error: "User already exists" });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const result = await pool.query(
      "INSERT INTO users (email, password, name, created_at) VALUES ($1, $2, $3, NOW()) RETURNING id, email, name, created_at",
      [email, hashedPassword, name]
    );

    const user = result.rows[0];

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: "24h" }
    );

    // Cache user data in Redis
    await redisClient.setEx(
      `user:${user.id}`,
      3600,
      JSON.stringify({
        id: user.id,
        email: user.email,
        name: user.name,
      })
    );

    logger.info("User registered successfully", {
      userId: user.id,
      email: user.email,
    });

    res.status(201).json({
      message: "User created successfully",
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        created_at: user.created_at,
      },
      token,
    });
  } catch (error) {
    logger.error("User registration error", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

app.post("/api/v1/users/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({ error: "Email and password are required" });
    }

    // Find user
    const result = await pool.query(
      "SELECT id, email, password, name FROM users WHERE email = $1",
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    const user = result.rows[0];

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password);

    if (!isValidPassword) {
      return res.status(401).json({ error: "Invalid credentials" });
    }

    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: "24h" }
    );

    // Cache user data in Redis
    await redisClient.setEx(
      `user:${user.id}`,
      3600,
      JSON.stringify({
        id: user.id,
        email: user.email,
        name: user.name,
      })
    );

    logger.info("User logged in successfully", {
      userId: user.id,
      email: user.email,
    });

    res.json({
      message: "Login successful",
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
      },
      token,
    });
  } catch (error) {
    logger.error("User login error", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

app.get("/api/v1/users/profile", async (req, res) => {
  try {
    const token = req.headers.authorization?.replace("Bearer ", "");

    if (!token) {
      return res.status(401).json({ error: "No token provided" });
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Try to get user from cache first
    const cachedUser = await redisClient.get(`user:${decoded.userId}`);

    if (cachedUser) {
      const user = JSON.parse(cachedUser);
      return res.json({ user });
    }

    // Get user from database
    const result = await pool.query(
      "SELECT id, email, name, created_at FROM users WHERE id = $1",
      [decoded.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    const user = result.rows[0];

    // Cache user data
    await redisClient.setEx(
      `user:${user.id}`,
      3600,
      JSON.stringify({
        id: user.id,
        email: user.email,
        name: user.name,
      })
    );

    res.json({ user });
  } catch (error) {
    if (error.name === "JsonWebTokenError") {
      return res.status(401).json({ error: "Invalid token" });
    }
    logger.error("Get user profile error", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  logger.error("Unhandled error", error);
  res.status(500).json({ error: "Internal server error" });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: "Not found" });
});

// Start server
async function startServer() {
  try {
    // Connect to Redis
    await redisClient.connect();

    // Test database connection
    await pool.query("SELECT 1");
    logger.info("Database connection established");

    // Start server
    app.listen(PORT, () => {
      logger.info(`User service listening on port ${PORT}`);
    });
  } catch (error) {
    logger.error("Failed to start server", error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on("SIGTERM", async () => {
  logger.info("SIGTERM received, shutting down gracefully");
  await redisClient.quit();
  await pool.end();
  process.exit(0);
});

process.on("SIGINT", async () => {
  logger.info("SIGINT received, shutting down gracefully");
  await redisClient.quit();
  await pool.end();
  process.exit(0);
});

startServer();
