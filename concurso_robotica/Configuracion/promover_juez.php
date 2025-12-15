<?php
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
error_reporting(0);
ini_set('display_errors', 0);

session_start();
require_once 'conexion.php';

$response = ["success" => false, "message" => "Acción no válida"];

try {
    if (!isset($_SESSION['user_id']) || $_SESSION['user_role'] !== 'ADMIN') {
        throw new Exception("Acceso denegado.");
    }

    $method = $_SERVER['REQUEST_METHOD'];

    if ($method === 'GET') {
        $action = $_GET['action'] ?? '';

        if ($action === 'listar_usuarios') {
            $stmt = $pdo->prepare("CALL Sp_Admin_ListarUsuariosCandidatos()");
            $stmt->execute();
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode(["success" => true, "data" => $data]);
            exit;
        }
        if ($action === 'obtener_catalogos') {
            $stmt = $pdo->prepare("CALL Sp_AdminListarEventosActivos()");
            $stmt->execute();
            $eventos = $stmt->fetchAll(PDO::FETCH_ASSOC);
            $stmt->closeCursor();

            $stmt = $pdo->prepare("CALL Sp_AdminListarCategorias()");
            $stmt->execute();
            $categorias = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            echo json_encode(["success" => true, "eventos" => $eventos, "categorias" => $categorias]);
            exit;
        }
        if ($action === 'jueces_disponibles') {
            $stmt = $pdo->prepare("CALL ListarJuecesDisponibles()");
            $stmt->execute();
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode(["success" => true, "data" => $data]);
            exit;
        }
        if ($action === 'jueces_asignados') {
            $idEvento = $_GET['id_evento'] ?? 0;
            $stmt = $pdo->prepare("CALL Sp_ListarJuecesDeEvento(:ide)");
            $stmt->bindParam(':ide', $idEvento);
            $stmt->execute();
            $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode(["success" => true, "data" => $data]);
            exit;
        }
    }

    if ($method === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true);
        $accion = $input['accion'] ?? '';

        if ($accion === 'actualizar_rol') {
            $idUsuario = $input['id'];
            $nuevoRol = $input['rol'];

            
            $stmt = $pdo->prepare("CALL ActualizarRolUsuario(:id, :rol)");
            $stmt->bindParam(':rol', $nuevoRol);
            $stmt->bindParam(':id', $idUsuario);
            $stmt->execute();
            
            $res = $stmt->fetch(PDO::FETCH_ASSOC);
            $mensaje = $res['mensaje'] ?? 'Error';

            if (strpos($mensaje, 'ÉXITO') !== false) {
                echo json_encode(["success" => true, "message" => $mensaje]);
            } else {
                throw new Exception($mensaje);
            }
            exit;
        }

        if ($accion === 'asignar_juez_evento') {
            $idEvento = $input['id_evento'];
            $idJuez = $input['id_juez'];
            $idCategoria = $input['id_categoria'];

            
            $stmt = $pdo->prepare("CALL AsignarJuezEvento(:ide, :idj, :idc)");
            $stmt->bindParam(':ide', $idEvento);
            $stmt->bindParam(':idj', $idJuez);
            $stmt->bindParam(':idc', $idCategoria);
            $stmt->execute();
            
            $output = $stmt->fetch(PDO::FETCH_ASSOC);
            $mensaje = $output['mensaje'] ?? 'Error';

            if (strpos($mensaje, 'ÉXITO') !== false) {
                echo json_encode(["success" => true, "message" => "Asignación exitosa."]);
            } else {
                echo json_encode(["success" => false, "message" => $mensaje]);
            }
            exit;
        }

        if ($accion === 'quitar_juez_evento') {
            $idEvento = $input['id_evento'];
            $idJuez = $input['id_juez'];
            $idCategoria = $input['id_categoria'];

            $stmt = $pdo->prepare("CALL QuitarJuezEvento(:ide, :idj, :idc)");
            $stmt->bindParam(':ide', $idEvento);
            $stmt->bindParam(':idj', $idJuez);
            $stmt->bindParam(':idc', $idCategoria);
            
            if ($stmt->execute()) {
                echo json_encode(["success" => true, "message" => "Juez removido correctamente."]);
            } else {
                throw new Exception("Error al remover juez.");
            }
            exit;
        }
    }

} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>