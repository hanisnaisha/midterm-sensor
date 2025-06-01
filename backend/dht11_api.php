<?php
// Set header to allow cross-origin requests and specify content type
header('Access-Control-Allow-Origin: *');
header('Content-Type: application/json');

// Read the raw POST data
$rawData = file_get_contents("php://input");

// Decode JSON payload
$data = json_decode($rawData, true);

// Validate that data was received
if ($data === null) {
    echo json_encode([
        'success' => false,
        'error' => 'Invalid or empty JSON input',
        'raw_input' => $rawData
    ]);
    exit;
}

// Extract variables safely
$device_id   = $data['device_id']   ?? null;
$temperature = $data['temperature'] ?? null;
$humidity    = $data['humidity']    ?? null;
$relay_state = $data['relay_state'] ?? null;
$timestamp   = $data['timestamp']   ?? time();

// Add optional validation here if needed

// TODO: Replace with your actual database insert logic
// For now, we just return the received data for debugging
$response = [
    'success'     => true,
    'device_id'   => $device_id,
    'temperature' => $temperature,
    'humidity'    => $humidity,
    'relay_state' => $relay_state,
    'timestamp'   => $timestamp
];

echo json_encode($response);
?>
