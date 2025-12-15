<?php
header('Content-Type: application/json; charset=utf-8');
require_once 'conexion.php';
session_start();

$response = ["success" => false, "message" => "Acceso denegado"];

try {
    if (!isset($_SESSION['user_id'])) throw new Exception("Sesión no iniciada");

    $rol = $_SESSION['user_role'];
    $idUsuario = $_SESSION['user_id'];
    $action = $_GET['action'] ?? '';

    // ====================================================
    //  NUEVO: OBTENER CATALOGOS (ACCESIBLE PARA TODOS)
    // ====================================================
    if ($action === 'obtener_catalogos') {
        // 1. Eventos Activos
        $stmt = $pdo->prepare("CALL Sp_AdminListarEventosActivos()");
        $stmt->execute();
        $eventos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $stmt->closeCursor();

        // 2. Categorías
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

    // ----------------------------------------------------
    // 1. REPORTES EXCLUSIVOS DE ADMINISTRADOR
    // ----------------------------------------------------
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

    // ----------------------------------------------------
    // 2. REPORTE GLOBAL (ADMIN, COACH, JUEZ)
    // ----------------------------------------------------
    if ($action === 'tabla_global') {
        $idEvento = $_GET['id_evento'];
        $idCategoria = $_GET['id_categoria'];
        
        $stmt = $pdo->prepare("CALL Sp_Reporte_TablaGlobal(:ev, :cat)");
        $stmt->execute([':ev' => $idEvento, ':cat' => $idCategoria]);
        echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
        exit;
    }

    // ----------------------------------------------------
    // 3. HERRAMIENTAS DE COACH (DESGLOSE)
    // ----------------------------------------------------
    
    // A. Listar mis equipos evaluados
    if ($action === 'mis_equipos_evaluados') {
        if ($rol !== 'COACH' && $rol !== 'COACH_JUEZ') throw new Exception("Solo Coaches.");
        
        $stmt = $pdo->prepare("CALL Sp_Coach_ListarMisEquiposEvaluados(:id)");
        $stmt->execute([':id' => $idUsuario]);
        echo json_encode(["success" => true, "data" => $stmt->fetchAll(PDO::FETCH_ASSOC)]);
        exit;
    }

    // B. Ver detalle específico
    if ($action === 'detalle_mi_equipo') {
        if ($rol !== 'COACH' && $rol !== 'COACH_JUEZ') throw new Exception("Solo Coaches.");

        $idEquipo = $_GET['id_equipo'];
        
        $stmt = $pdo->prepare("CALL Sp_Reporte_DetalleMiEquipo(:eq, :coach)");
        $stmt->execute([':eq' => $idEquipo, ':coach' => $idUsuario]);
        $data = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($data && isset($data['resultado']) && $data['resultado'] === 'ERROR') {
            throw new Exception("No autorizado o equipo no encontrado.");
        }

        echo json_encode(["success" => true, "data" => $data]);
        exit;
    }
    
    // ----------------------------------------------------
    // 4. AUXILIAR (Obtener Rol para el Frontend)
    // ----------------------------------------------------
    if ($action === 'get_session_role') {
        echo json_encode(["success" => true, "role" => $rol]);
        exit;
    }

} catch (Exception $e) {
    echo json_encode(["success" => false, "message" => $e->getMessage()]);
}
?>