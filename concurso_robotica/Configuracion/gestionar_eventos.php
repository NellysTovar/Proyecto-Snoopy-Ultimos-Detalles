<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
error_reporting(0); 
ini_set('display_errors', 0);

$response = ["success" => false, "message" => "Error desconocido"];

try {
    $rutaConexion = __DIR__ . '/conexion.php';
    if (!file_exists($rutaConexion)) throw new Exception("Error conexión.");
    require_once $rutaConexion;

    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET') {
        $stmt = $pdo->prepare("CALL Sp_AdminListarEventos()");
        $stmt->execute();
        $eventos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode(["success" => true, "data" => $eventos]);
        exit;
    }

    if ($method === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        $accion = $input['accion'] ?? '';

        if ($accion === 'crear') {
            $nombre = $input['nombre'];
            $fecha  = $input['fecha'];
            $lugar  = $input['lugar'];

            $stmt = $pdo->prepare("CALL CrearEvento(:nombre, :fecha, :lugar)");
            $stmt->bindParam(':nombre', $nombre);
            $stmt->bindParam(':fecha', $fecha);
            $stmt->bindParam(':lugar', $lugar);
            $stmt->execute();
            
            $res = $stmt->fetch(PDO::FETCH_ASSOC);
            $stmt->closeCursor();
            
            $msg = $res['mensaje'] ?? 'Error desconocido';
            $response = ["success" => (strpos($msg, 'ÉXITO') !== false), "message" => $msg];
        } 
        elseif ($accion === 'eliminar') {
            $id = $input['id'];
            $stmt = $pdo->prepare("CALL EliminarEvento(:id)");
            $stmt->bindParam(':id', $id);
            $stmt->execute();
            
            $res = $stmt->fetch(PDO::FETCH_ASSOC);
            $stmt->closeCursor();
            
            $msg = $res['mensaje'] ?? 'Error desconocido';
            $response = ["success" => (strpos($msg, 'ÉXITO') !== false), "message" => $msg];
        } 
        else {
            throw new Exception("Acción no reconocida");
        }
    }

} catch (Exception $e) {
    $response["message"] = $e->getMessage();
}

echo json_encode($response);
?>