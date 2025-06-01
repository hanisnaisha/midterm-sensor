<?php
// CORS headers
header("Access-Control-Allow-Origin: *"); 
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Content-Type: application/json; charset=UTF-8");

// Handle preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

class DBConnection {
    private $host = 'localhost';
    private $db_name = 'humancmt_hn_dht11'; 
    private $username = 'humancmt_hn_dht11_admin';
    private $password = 'Tz=+xnYmSh8N';
    private $conn;

    public function __construct() {
        $this->connect();
    }

    private function connect() {
        try {
            $dsn = "mysql:host={$this->host};dbname={$this->db_name};charset=utf8mb4";
            $this->conn = new PDO($dsn, $this->username, $this->password);
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            error_log("Connecting to DB as {$this->username}@{$this->host}");
        } catch (PDOException $e) {
            error_log("DB connection failed: " . $e->getMessage());
            die(json_encode(['status' => 'error', 'message' => 'Database connection failed: ' . $e->getMessage()]));
        }
    }

    public function getConnection() {
        return $this->conn;
    }

    public function close() {
        $this->conn = null;
    }

    // Insert sensor data from Arduino with basic validation
    public function insertDHTData($device_id, $temperature, $humidity, $relay_state, $timestamp) {
        // Basic input validation (optional)
        if (!is_int($device_id) || !is_numeric($temperature) || !is_numeric($humidity) || !is_int($relay_state) || !is_int($timestamp)) {
            throw new InvalidArgumentException("Invalid input types for insertDHTData");
        }

        $query = "INSERT INTO tbl_sensordata (device_id, temperature, humidity, relay_state, timestamp) 
                  VALUES (:device_id, :temperature, :humidity, :relay_state, :timestamp)";

        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':device_id', $device_id, PDO::PARAM_INT);
        $stmt->bindParam(':temperature', $temperature);
        $stmt->bindParam(':humidity', $humidity);
        $stmt->bindParam(':relay_state', $relay_state, PDO::PARAM_INT);
        $stmt->bindParam(':timestamp', $timestamp, PDO::PARAM_INT);

        return $stmt->execute();
    }

    // Fetch latest N readings with sanitized limit
    public function getLatestReadings($device_id, $limit = 50) {
        if (!is_int($device_id)) {
            throw new InvalidArgumentException("device_id must be an integer");
        }

        // Ensure limit is within range
        $limit = max(1, min($limit, 1000));

        // Note: cannot bind LIMIT param in PDO with MySQL, so ensure $limit is safe
        $query = "SELECT * FROM tbl_sensordata WHERE device_id = :device_id 
                  ORDER BY timestamp DESC LIMIT $limit";
        
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':device_id', $device_id, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    // Fetch the most recent single reading
    public function getLatestSingleReading($device_id) {
        if (!is_int($device_id)) {
            throw new InvalidArgumentException("device_id must be an integer");
        }

        $query = "SELECT * FROM tbl_sensordata WHERE device_id = :device_id 
                  ORDER BY timestamp DESC LIMIT 1";

        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(':device_id', $device_id, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetch(PDO::FETCH_ASSOC);
    }
}

// Note: Removed bottom test block for cleaner production code
?>
