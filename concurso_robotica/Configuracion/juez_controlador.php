<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
error_reporting(0);
ini_set('display_errors', 0);

session_start();
require_once 'conexion.php';

$response = ["success" => false, "message" => "Acción no válida"];

try {
    if (!isset($_SESSION['user_id'])) throw new Exception("Sesión expirada.");

    $idJuez = $_SESSION['user_id'];
    $rol = $_SESSION['user_role'] ?? '';

    if ($rol !== 'JUEZ' && $rol !== 'COACH_JUEZ' && $rol !== 'ADMIN') {
        throw new Exception("No tienes permisos de Juez.");
    }

    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET') {
        $action = $_GET['action'] ?? '';

        if ($action === 'listar_proyectos') {
            $categoria = $_GET['categoria'] ?? 'TODOS';
            
            if ($categoria === 'TODOS') {
                $stmt = $pdo->prepare("CALL Sp_Juez_ObtenerCategoriasAsignadas(:idj)");
                $stmt->bindParam(':idj', $idJuez);
                $stmt->execute();
                $cats = $stmt->fetchAll(PDO::FETCH_COLUMN);
                $stmt->closeCursor();

                $todosLosProyectos = [];
                foreach($cats as $catNombre) {
                    $stmt = $pdo->prepare("CALL Sp_Juez_ListarProyectos(:idj, :nomCat)");
                    $stmt->bindParam(':idj', $idJuez);
                    $stmt->bindParam(':nomCat', $catNombre);
                    $stmt->execute();
                    $proyectos = $stmt->fetchAll(PDO::FETCH_ASSOC);
                    $stmt->closeCursor();
                    foreach($proyectos as &$p) { $p['nombre_categoria'] = $catNombre; }
                    $todosLosProyectos = array_merge($todosLosProyectos, $proyectos);
                }
                $response = ["success" => true, "data" => $todosLosProyectos];
            } else {
                $stmt = $pdo->prepare("CALL Sp_Juez_ListarProyectos(:idj, :nomCat)");
                $stmt->bindParam(':idj', $idJuez);
                $stmt->bindParam(':nomCat', $categoria);
                $stmt->execute();
                $proyectos = $stmt->fetchAll(PDO::FETCH_ASSOC);
                foreach($proyectos as &$p) { $p['nombre_categoria'] = $categoria; }
                $response = ["success" => true, "data" => $proyectos];
            }
        }
        elseif ($action === 'obtener_categorias') {
            $stmt = $pdo->prepare("CALL Sp_Juez_ObtenerCategoriasAsignadas(:idj)");
            $stmt->bindParam(':idj', $idJuez);
            $stmt->execute();
            $cats = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $response = ["success" => true, "data" => $cats];
        }
        elseif ($action === 'obtener_evaluacion') {
            $idEquipo = $_GET['id_equipo'] ?? 0;
            $stmt = $pdo->prepare("CALL Sp_ObtenerDetalleEvaluacion(:ide)");
            $stmt->bindParam(':ide', $idEquipo);
            $stmt->execute();
            $detalle = $stmt->fetch(PDO::FETCH_ASSOC);
            $stmt->closeCursor();
            $response = ["success" => true, "data" => $detalle ?: null];
        }
    }

    if ($method === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        $action = $input['action'] ?? '';
        
        if ($action === 'guardar_evaluacion') {
            $idEquipo = $input['id_equipo'] ?? 0;
            $total = $input['total'] ?? 0;
            $detalles = isset($input['detalles']) ? json_encode($input['detalles']) : null;

            // MODIFICADO: CALL directo, sin @variables
            $stmt = $pdo->prepare("CALL RegistrarEvaluacion(:ide, :idj, :tot, :det)");
            $stmt->bindParam(':ide', $idEquipo);
            $stmt->bindParam(':idj', $idJuez);
            $stmt->bindParam(':tot', $total);
            $stmt->bindParam(':det', $detalles);
            $stmt->execute();
            
            // MODIFICADO: Fetch directo
            $output = $stmt->fetch(PDO::FETCH_ASSOC);
            $stmt->closeCursor();

            $mensaje = $output['mensaje'] ?? 'Error desconocido';

            if (strpos($mensaje, 'ÉXITO') !== false) {
                $response = ["success" => true, "message" => $mensaje];
            } else {
                throw new Exception($mensaje);
            }
        }
    }

} catch (Exception $e) {
    $response["success"] = false;
    $response["message"] = $e->getMessage();
}

echo json_encode($response);
?>