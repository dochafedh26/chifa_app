<?php
// api.php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");

// Security key - must match the one sent by the Flutter app
$API_KEY = getenv('API_KEY') ?: 'chifa_secret_key_2026';

if (!isset($_POST['api_key']) || $_POST['api_key'] !== $API_KEY) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// Database Credentials
$host = getenv('DB_HOST') ?: 'localhost';
$user = getenv('DB_USER') ?: 'root';
$pass = getenv('DB_PASSWORD') ?: '';
$db = getenv('DB_NAME') ?: 'chifa';
$port = (int)(getenv('DB_PORT') ?: 3306);

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

try {
    // Standard connection for AwardSpace
    $conn = new mysqli($host, $user, $pass, $db, $port);
    $conn->set_charset("utf8mb4");
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Connection failed: ' . $e->getMessage()]);
    exit;
}

$action = $_POST['action'] ?? '';
$sql = $_POST['sql'] ?? '';
$params = isset($_POST['params']) ? json_decode($_POST['params'], true) : [];

if (empty($sql)) {
    http_response_code(400);
    echo json_encode(['error' => 'SQL query is missing']);
    exit;
}

try {
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        throw new Exception($conn->error);
    }

    if (!empty($params)) {
        $types = '';
        $bindParams = [];
        foreach ($params as $param) {
            if (is_int($param)) {
                $types .= 'i';
            } elseif (is_float($param)) {
                $types .= 'd';
            } else {
                $types .= 's';
            }
            $bindParams[] = $param;
        }
        $stmt->bind_param($types, ...$bindParams);
    }

    if (!$stmt->execute()) {
        throw new Exception($stmt->error);
    }

    if ($action === 'query') {
        $result = $stmt->get_result();
        $data = [];
        if ($result) {
            while ($row = $result->fetch_assoc()) {
                $data[] = $row;
            }
        }
        echo json_encode(['success' => true, 'data' => $data]);

    } elseif ($action === 'insert') {
        echo json_encode(['success' => true, 'insertId' => $stmt->insert_id]);

    } elseif ($action === 'execute') {
        echo json_encode(['success' => true, 'affectedRows' => $stmt->affected_rows]);

    } else {
        echo json_encode(['error' => 'Invalid action type requested']);
    }

    $stmt->close();
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}

$conn->close();
?>