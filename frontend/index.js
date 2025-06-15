const express = require("express");
const app = express();
const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
  res.json({
    message: "E-Commerce Frontend is running",
    apiUrl: process.env.REACT_APP_API_URL || "http://localhost:9080",
    timestamp: new Date().toISOString(),
  });
});

app.listen(PORT, () => {
  console.log(`Frontend server listening on port ${PORT}`);
});
