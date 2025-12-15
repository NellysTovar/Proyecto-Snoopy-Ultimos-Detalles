<?php
header('Content-Type: application/json; charset=utf-8');
// Permitir CORS si es necesario, aunque en mismo dominio no es obligatorio
header('Access-Control-Allow-Origin: *'); 
require_once 'conexion.php';
session_start();

$response = ["success" => false, "message" => "Acceso denegado"];

try {
    // Verificar sesión iniciada
    if (!isset($_SESSION['user_id'])) throw new Exception("Sesión no iniciada");

    $rol = $_SESSION['user_role'] ?? '';
    $idUsuario = $_SESSION['user_id'];
    $action = $_GET['action'] ?? '';

    // --- ACCIÓN 1: Obtener catálogos para los filtros (Eventos y Categorías) ---
    if ($action === 'obtener_catalogos') {
        
        // Listar Eventos Activos
        $stmt = $pdo->prepare("CALL Sp_AdminListarEventosActivos()");
        $stmt->execute();
        $eventos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $stmt->closeCursor();

        // Listar Categorías
        $stmt = $pdo->prepare("CALL Sp_AdminListarCategorias()");
        $stmt->execute();
        $categorias = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode([
            "success" => true, 
            "eventos" => $eventos, 
            "categorias" => $categorias
        ]);
        exit;
    }

    // --- ACCIÓN 2: Reportes exclusivos de ADMINISTRADOR ---
    if (in_array($action, ['admin_top3', 'admin_lista_equipos', 'admin_estadisticas'])) {
        
        if ($rol !== 'ADMIN') throw new Exception("Permisos insuficientes. Solo Administrador.");

        if ($action === 'admin_top3') {
            $idEvento = $_GET['id_evento'];
            $idCategoria = $_GET['id_categoria'];
            $stmt = $pdo->prepare("CALL Sp_Reporte_Top3(:ev, :cat)");
            $stmt->execute([':ev' => $idEvento, ':cat' => $idCategoria]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
        }

        if ($action === 'admin_lista_equipos') {
            $idEvento = $_GET['id_evento'];
            $idCategoria = $_GET['id_categoria'];
            $stmt = $pdo->prepare("CALL Sp_Reporte_EquiposPorCategoria(:ev, :cat)");
            $stmt->execute([':ev' => $idEvento, ':cat' => $idCategoria]);
            echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
        }

        if ($action === 'admin_estadisticas') {
            $stmt = $pdo->prepare("CALL Sp_Reporte_ConteoPorEvento()");
            $stmt->execute();
            echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
        }
        exit;
    }

    // --- ACCIÓN 3: Tabla Global (Disponible para Jueces, Coaches y Admin) ---
    if ($action === 'tabla_global') {
        $idEvento = $_GET['id_evento'];
        $idCategoria = $_GET['id_categoria'];
        
        $stmt = $pdo->prepare("CALL Sp_Reporte_TablaGlobal(:ev, :cat)");
        $stmt->execute([':ev' => $idEvento, ':cat' => $idCategoria]);
        echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
        exit;
    }

    // --- ACCIÓN 4: Acciones exclusivas de COACH ---
    if ($action === 'mis_equipos_evaluados') {
        if ($rol !== 'COACH' && $rol !== 'COACH_JUEZ') throw new Exception("Solo Coaches.");
        
        $stmt = $pdo->prepare("CALL Sp_Coach_ListarMisEquiposEvaluados(:id)");
        $stmt->execute([':id' => $idUsuario]);
        echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
        exit;
    }

    if ($action === 'detalle_mi_equipo') {
        if ($rol !== 'COACH' && $rol !== 'COACH_JUEZ') throw new Exception("Solo Coaches.");

        $idEquipo = $_GET['id_equipo'];
        
        $stmt = $pdo->prepare("CALL Sp_Reporte_DetalleMiEquipo(:eq, :coach)");
        $stmt->execute([':eq' => $idEquipo, ':coach' => $idUsuario]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);

        // Validar si el SP devolvió error de permiso
        if ($data && isset($data['resultado']) && $data['resultado'] === 'ERROR') {
            throw new Exception("No autorizado o equipo no encontrado.");
        }

        echo json_encode(["success" => true, "data" => $data]);
        exit;
    }
    
    // --- ACCIÓN 5: Obtener Rol Actual (Para la UI) ---
    if ($action === 'get_session_role') {
        echo json_encode(["success" => true, "role" => $rol]);
        exit;
    }

} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>