const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const rateLimit = require("express-rate-limit");
const { Pool } = require("pg");
const redis = require("redis");
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
  defaultMeta: { service: "catalog-service" },
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
      service: "catalog-service",
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
    });
  } catch (error) {
    logger.error("Health check failed", error);
    res.status(503).json({
      status: "unhealthy",
      service: "catalog-service",
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

// Catalog routes
app.get("/api/v1/products", async (req, res) => {
  try {
    const { page = 1, limit = 10, category } = req.query;
    const offset = (page - 1) * limit;

    // Try to get from cache first
    const cacheKey = `products:${page}:${limit}:${category || "all"}`;
    const cachedProducts = await redisClient.get(cacheKey);

    if (cachedProducts) {
      return res.json(JSON.parse(cachedProducts));
    }

    // Get from database
    let query =
      "SELECT id, name, description, price, category, stock FROM products ORDER BY created_at DESC LIMIT $1 OFFSET $2";
    let params = [limit, offset];

    if (category) {
      query =
        "SELECT id, name, description, price, category, stock FROM products WHERE category = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3";
      params = [category, limit, offset];
    }

    const result = await pool.query(query, params);

    // Cache the result
    await redisClient.setEx(
      cacheKey,
      300,
      JSON.stringify({
        products: result.rows,
        page: parseInt(page),
        limit: parseInt(limit),
        total: result.rows.length,
      })
    );

    res.json({
      products: result.rows,
      page: parseInt(page),
      limit: parseInt(limit),
      total: result.rows.length,
    });
  } catch (error) {
    logger.error("Get products error", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

app.get("/api/v1/products/:id", async (req, res) => {
  try {
    const { id } = req.params;

    // Try to get from cache first
    const cacheKey = `product:${id}`;
    const cachedProduct = await redisClient.get(cacheKey);

    if (cachedProduct) {
      return res.json(JSON.parse(cachedProduct));
    }

    // Get from database
    const result = await pool.query(
      "SELECT id, name, description, price, category, stock, created_at FROM products WHERE id = $1",
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: "Product not found" });
    }

    const product = result.rows[0];

    // Cache the result
    await redisClient.setEx(cacheKey, 600, JSON.stringify(product));

    res.json(product);
  } catch (error) {
    logger.error("Get product error", error);
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
      logger.info(`Catalog service listening on port ${PORT}`);
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
