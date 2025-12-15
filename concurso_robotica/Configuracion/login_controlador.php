<?php

error_reporting(0);
ini_set('display_errors', 0);

session_start();
header('Content-Type: application/json');

$response = [
    "success" => false, 
    "message" => "Error desconocido",
    "redirect" => ""
];

try {
    
    $rutaConexion = __DIR__ . '/conexion.php';
    
    if (!file_exists($rutaConexion)) {
        throw new Exception("Error interno: No se encuentra el archivo de conexión en " . $rutaConexion);
    }
    
    require_once $rutaConexion;

    
    if (!isset($pdo)) {
        throw new Exception("Error interno: Fallo la conexión a la base de datos.");
    }

    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        
        $input = json_decode(file_get_contents('php://input'), true);
        
        
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception("Datos inválidos recibidos (JSON mal formado).");
        }
        
        $email = $input['email'] ?? '';
        $password = $input['password'] ?? '';
        $role = $input['role'] ?? '';

        if (empty($email) || empty($password) || empty($role)) {
            
            throw new Exception("Por favor complete todos los campos.");
        }

        
        $stmt = $pdo->prepare("CALL sp_ObtenerDatosLogin(?, ?)");
        $stmt->execute([$email, $role]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        $stmt->closeCursor();

        if ($user) {
            if ($user['activo'] == 0) {
                $response["message"] = "Esta cuenta ha sido desactivada. Contacte al administrador.";
            } 
            else if ($password === $user['password_hash']) {
                $_SESSION['user_id'] = $user['id_usuario'];
                $_SESSION['user_name'] = $user['nombres'] . ' ' . $user['apellidos'];
                $_SESSION['user_role'] = $user['tipo_usuario'];
                
                $response["success"] = true;
                $response["message"] = "Login correcto";
                
                
                if ($user['tipo_usuario'] == 'ADMIN') {
                    $response["redirect"] = "adminPanel.html";
                } elseif ($role == 'JUEZ') { 
                    $response["redirect"] = "juezPanel.html";
                } elseif ($role == 'COACH') { 
                    $response["redirect"] = "coachPanel.html";
                } else {
                     $response["redirect"] = "login.html";
                }
            } else {
                $response["message"] = "Contraseña incorrecta.";
            }
        } else {
            $response["message"] = "Usuario no encontrado o no tiene permisos de " . $role . ".";
        }

    } else {
        $response["message"] = "Método no permitido.";
    }

} catch (PDOException $e) {
    
    $response["message"] = "Error de Base de Datos: " . $e->getMessage();
} catch (Exception $e) {
    
    $response["message"] = $e->getMessage();
}



echo json_encode($response);
?>