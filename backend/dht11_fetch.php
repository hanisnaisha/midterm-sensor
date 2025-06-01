<?php
require_once 'dbconnect.php';

// Security headers
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('X-Frame-Options: DENY'); // Prevent clickjacking

// Only process GET requests
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405); // Method Not Allowed
    echo json_encode(['status' => 'error', 'message' => 'Only GET method is allowed']);
    exit;
}

// Get parameters with defaults and basic validation
$device_id = isset($_GET['device_id']) ? (int)$_GET['device_id'] : null; // Require device_id
$limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;

// Validate required device_id
if (!isset($_GET['device_id']) || $_GET['device_id'] === '') {
    http_response_code(400); // Bad Request
    echo json_encode(['status' => 'error', 'message' => 'Missing device_id parameter']);
    exit;
}
$device_id = (int)$_GET['device_id'];

// Validate limit range
$limit = max(1, min($limit, 1000)); // Ensure limit is between 1 and 1000

try {
    // Create a new DBConnection instance
    $db = new DBConnection();
    
    // Fetch data using the DBConnection method
    $data = $db->getLatestReadings($device_id, $limit);
    
    // Close the database connection
    $db->close();
    
    // Send success response
    echo json_encode([
        "status" => "success",
        "device_id" => $device_id,
        "count" => count($data),
        "data" => $data
    ]);
    
} catch (Exception $e) {
    // Handle potential database connection errors or other exceptions
    http_response_code(500); // Internal Server Error
    echo json_encode(["status" => "error", "message" => "Failed to fetch data: " . $e->getMessage()]);
}
?> 