DROP DATABASE IF EXISTS concurso_robotica;
CREATE DATABASE concurso_robotica;
USE concurso_robotica;

-- =============================================
-- 1. TABLAS (ESTRUCTURA)
-- =============================================

CREATE TABLE usuarios (
    id_usuario INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    escuela_proc varchar (150) not null,
    tipo_usuario ENUM('ADMIN', 'JUEZ', 'COACH', 'COACH_JUEZ') NOT NULL,
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE eventos (
    id_evento INT PRIMARY KEY AUTO_INCREMENT,
    nombre_evento VARCHAR(200) NOT NULL,
    fecha_evento DATE NOT NULL,
    lugar VARCHAR(200) NOT NULL,
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE categorias (
    id_categoria INT PRIMARY KEY AUTO_INCREMENT,
    nombre_categoria VARCHAR(50) NOT NULL UNIQUE,
    edad_minima INT NOT NULL,
    edad_maxima INT NOT NULL
);

CREATE TABLE equipos (
    id_equipo INT PRIMARY KEY AUTO_INCREMENT,
    nombre_equipo VARCHAR(150) NOT NULL,
    nombre_prototipo VARCHAR(200) NOT NULL,            
    id_evento INT NOT NULL,
    id_categoria INT NOT NULL,
    id_coach INT NOT NULL,
    escuela_procedencia varchar (150) not null,
    descripcion_proyecto TEXT,
    estado_proyecto ENUM('PENDIENTE', 'EVALUADO', 'DESCALIFICADO') DEFAULT 'PENDIENTE', 
    fecha_registro DATETIME DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (id_evento) REFERENCES eventos(id_evento),
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    FOREIGN KEY (id_coach) REFERENCES usuarios(id_usuario)
);

CREATE TABLE integrantes (
    id_integrante INT PRIMARY KEY AUTO_INCREMENT,
    id_equipo INT NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL,
    edad INT NOT NULL,
    grado INT NOT NULL DEFAULT 1,
    escuela VARCHAR(150),
    FOREIGN KEY (id_equipo) REFERENCES equipos(id_equipo) ON DELETE CASCADE
);

CREATE TABLE evaluaciones (
    id_evaluacion INT PRIMARY KEY AUTO_INCREMENT,
    id_equipo INT NOT NULL, 
    id_juez INT NOT NULL,  
    fecha_evaluacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    puntuacion_total INT,  
    detalles_evaluacion JSON DEFAULT NULL,
    FOREIGN KEY (id_equipo) REFERENCES equipos(id_equipo) ON DELETE CASCADE,
    FOREIGN KEY (id_juez) REFERENCES usuarios(id_usuario),
    UNIQUE KEY unique_evaluacion_equipo (id_equipo) 
);

CREATE TABLE jueces_eventos (
    id_asignacion INT PRIMARY KEY AUTO_INCREMENT,
    id_evento INT NOT NULL,
    id_juez INT NOT NULL,
    id_categoria INT NOT NULL,
    fecha_asignacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_evento) REFERENCES eventos(id_evento) ON DELETE CASCADE,
    FOREIGN KEY (id_juez) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    UNIQUE KEY unique_juez_evento_categoria (id_evento, id_juez, id_categoria)
);

-- Datos Semilla
INSERT INTO categorias(nombre_categoria,edad_minima,edad_maxima) VALUES
('PRIMARIA',6,12),('SECUNDARIA',13,15),('PREPARATORIA',16,18),('UNIVERSIDAD',18,25);

INSERT INTO usuarios(email,password_hash,nombres,apellidos,escuela_proc,tipo_usuario) VALUES
('admin@robotica.com','admin123','Admin','Sistema','SISTEMA','ADMIN');

-- =============================================
-- 2. FUNCIONES (ACTUALIZADAS Y CORREGIDAS)
-- =============================================

-- Permite crear funciones sin errores de permisos en algunos servidores
SET GLOBAL log_bin_trust_function_creators = 1;

DELIMITER //

CREATE FUNCTION VerificarEquipoRepetido(p_nombre_equipo VARCHAR(150), p_id_evento INT, p_id_categoria INT) 
RETURNS BOOLEAN DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE existe BOOLEAN DEFAULT FALSE;
    SELECT COUNT(*) > 0 INTO existe FROM equipos 
    WHERE nombre_equipo = p_nombre_equipo AND id_evento = p_id_evento AND id_categoria = p_id_categoria AND activo = TRUE;
    RETURN existe;
END//

CREATE FUNCTION VerificarEdadCategoria(p_edad INT, p_id_categoria INT)
RETURNS BOOLEAN DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE emin INT; 
    DECLARE emax INT;
    
    SET emin = 0;
    SET emax = 100;

    SELECT edad_minima, edad_maxima INTO emin, emax 
    FROM categorias 
    WHERE id_categoria = p_id_categoria;
    
    IF p_edad >= emin AND p_edad <= emax THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END//

CREATE FUNCTION VerificarGradoCategoria(p_grado INT, p_id_categoria INT)
RETURNS BOOLEAN DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE cat_nombre VARCHAR(50);
    
    SELECT nombre_categoria INTO cat_nombre 
    FROM categorias 
    WHERE id_categoria = p_id_categoria;
    
    IF cat_nombre = 'PRIMARIA' THEN 
        RETURN p_grado BETWEEN 1 AND 6;
    ELSEIF cat_nombre = 'SECUNDARIA' THEN 
        RETURN p_grado BETWEEN 1 AND 3;
    ELSEIF cat_nombre = 'PREPARATORIA' THEN 
        RETURN p_grado BETWEEN 1 AND 6;
    ELSEIF cat_nombre = 'UNIVERSIDAD' THEN 
        RETURN p_grado BETWEEN 1 AND 14; 
    ELSE 
        RETURN TRUE;
    END IF;
END //
DELIMITER ;

-- =============================================
-- 3. PROCEDIMIENTOS ALMACENADOS
-- =============================================

DELIMITER //

-- LOGIN
CREATE PROCEDURE sp_ObtenerDatosLogin(IN p_email VARCHAR(100), IN p_tipo VARCHAR(20))
BEGIN
    SELECT id_usuario, password_hash, nombres, apellidos, tipo_usuario, email, activo 
    FROM usuarios WHERE email = p_email AND (tipo_usuario = p_tipo OR tipo_usuario = 'COACH_JUEZ' OR p_tipo = 'ADMIN');
END //

-- REGISTRO USUARIO (Validación de Nombres Duplicados AÑADIDA)
CREATE PROCEDURE RegistrarUsuario(
    IN p_email VARCHAR(100), IN p_password_hash VARCHAR(255),
    IN p_nombres VARCHAR(100), IN p_apellidos VARCHAR(100),
    IN p_tipo_usuario ENUM('ADMIN','JUEZ','COACH'), IN p_escuela_proc VARCHAR(150)
)
BEGIN
    -- Validar Email
    IF EXISTS (SELECT 1 FROM usuarios WHERE email = p_email) THEN
        SELECT 'ERROR: El correo electrónico ya está registrado.' AS mensaje, 0 AS id;
    
    -- Validar Nombre Completo Duplicado (Requerimiento)
    ELSEIF EXISTS (SELECT 1 FROM usuarios WHERE nombres = p_nombres AND apellidos = p_apellidos) THEN
        SELECT 'ERROR: Ya existe un usuario registrado con ese Nombre y Apellido.' AS mensaje, 0 AS id;
        
    ELSE
        INSERT INTO usuarios(email, password_hash, nombres, apellidos, escuela_proc, tipo_usuario)
        VALUES(p_email, p_password_hash, p_nombres, p_apellidos, p_escuela_proc, p_tipo_usuario);
        SELECT 'ÉXITO: Usuario registrado correctamente.' AS mensaje, LAST_INSERT_ID() AS id;
    END IF;
END //

-- ACTUALIZAR ROL
CREATE PROCEDURE ActualizarRolUsuario(IN p_id_usuario INT, IN p_rol VARCHAR(20))
BEGIN
    UPDATE usuarios SET tipo_usuario = p_rol WHERE id_usuario = p_id_usuario;
    IF ROW_COUNT() > 0 THEN
        SELECT 'ÉXITO: Rol actualizado correctamente' AS mensaje;
    ELSE
        SELECT 'ERROR: No se pudo actualizar el rol (Usuario no encontrado o mismo rol)' AS mensaje;
    END IF;
END //

-- REGISTRO EQUIPO
CREATE PROCEDURE RegistrarEquipo(
    IN p_nombre VARCHAR(150), IN p_prototipo VARCHAR(200),
    IN p_id_evento INT, IN p_id_categoria INT, IN p_id_coach INT
)
BEGIN
    DECLARE v_escuela VARCHAR(150);
    SELECT escuela_proc INTO v_escuela FROM usuarios WHERE id_usuario = p_id_coach;

    IF VerificarEquipoRepetido(p_nombre, p_id_evento, p_id_categoria) THEN
        SELECT 'ERROR: Nombre de equipo duplicado en este evento' AS mensaje, 0 AS id;
    ELSE
        INSERT INTO equipos(nombre_equipo, nombre_prototipo, id_evento, id_categoria, id_coach, escuela_procedencia)
        VALUES(p_nombre, p_prototipo, p_id_evento, p_id_categoria, p_id_coach, v_escuela);
        SELECT 'ÉXITO: Equipo creado' AS mensaje, LAST_INSERT_ID() AS id;
    END IF;
END //

-- AGREGAR INTEGRANTE (Validación de Propiedad y Duplicados AÑADIDA)
CREATE PROCEDURE AgregarIntegrante(
    IN p_id_equipo INT, 
    IN p_nombre VARCHAR(150), 
    IN p_edad INT, 
    IN p_grado INT,
    IN p_id_coach_solicitante INT  -- Nuevo parámetro para seguridad
)
BEGIN
    DECLARE v_total INT; 
    DECLARE v_cat INT; 
    DECLARE v_escuela VARCHAR(150);
    DECLARE v_coach_real INT;
    
    -- 1. Verificar Propiedad (Seguridad: Coach solo edita sus equipos)
    SELECT id_coach INTO v_coach_real FROM equipos WHERE id_equipo = p_id_equipo;
    
    IF v_coach_real IS NULL THEN
        SELECT 'ERROR: El equipo no existe.' AS mensaje;
    ELSEIF v_coach_real <> p_id_coach_solicitante THEN
        SELECT 'ERROR: No tienes permiso para modificar este equipo (Pertenece a otro Coach).' AS mensaje;
    ELSE
        -- 2. Verificar Nombres Duplicados en Integrantes
        IF EXISTS (SELECT 1 FROM integrantes WHERE nombre_completo = p_nombre) THEN
            SELECT 'ERROR: Esta persona ya está registrada como integrante en el sistema.' AS mensaje;
        ELSE
            -- 3. Verificar Cupo
            SELECT COUNT(*) INTO v_total FROM integrantes WHERE id_equipo = p_id_equipo;
            
            IF v_total >= 3 THEN 
                SELECT 'ERROR: El equipo ya está lleno (Máximo 3 integrantes).' AS mensaje;
            ELSE
                SELECT id_categoria, escuela_procedencia INTO v_cat, v_escuela FROM equipos WHERE id_equipo = p_id_equipo;
                
                -- 4. Validar Reglas de Categoría
                IF NOT VerificarEdadCategoria(p_edad, v_cat) THEN 
                    SELECT 'ERROR: La edad del integrante no corresponde a la categoría del equipo.' AS mensaje;
                ELSEIF NOT VerificarGradoCategoria(p_grado, v_cat) THEN 
                    SELECT 'ERROR: El grado escolar no es válido para esta categoría.' AS mensaje;
                ELSE
                    INSERT INTO integrantes(id_equipo, nombre_completo, edad, grado, escuela)
                    VALUES(p_id_equipo, p_nombre, p_edad, p_grado, v_escuela);
                    SELECT 'ÉXITO: Integrante agregado correctamente.' AS mensaje;
                END IF;
            END IF;
        END IF;
    END IF;
END //

-- ELIMINAR INTEGRANTE
CREATE PROCEDURE EliminarIntegrante(IN p_id_integrante INT, IN p_id_coach INT)
BEGIN
    DECLARE v_id_equipo INT; DECLARE v_owner_coach INT;
    
    SELECT id_equipo INTO v_id_equipo FROM integrantes WHERE id_integrante = p_id_integrante;
    
    IF v_id_equipo IS NULL THEN
        SELECT 'ERROR: Integrante no encontrado' AS mensaje;
    ELSE
        SELECT id_coach INTO v_owner_coach FROM equipos WHERE id_equipo = v_id_equipo;
        IF v_owner_coach = p_id_coach THEN
            DELETE FROM integrantes WHERE id_integrante = p_id_integrante;
            SELECT 'ÉXITO: Integrante eliminado' AS mensaje;
        ELSE
            SELECT 'ERROR: No tienes permiso para eliminar este integrante' AS mensaje;
        END IF;
    END IF;
END //

-- CREAR EVENTO
CREATE PROCEDURE CrearEvento(IN p_nombre VARCHAR(200), IN p_fecha DATE, IN p_lugar VARCHAR(200))
BEGIN
    IF p_fecha < CURDATE() THEN
        SELECT 'ERROR: La fecha del evento no puede ser anterior a la actual' AS mensaje;
    ELSEIF EXISTS (SELECT 1 FROM eventos WHERE nombre_evento = p_nombre AND activo = TRUE) THEN
        SELECT 'ERROR: Ya existe un evento activo con ese nombre' AS mensaje;
    ELSEIF EXISTS (SELECT 1 FROM eventos WHERE fecha_evento = p_fecha AND lugar = p_lugar AND activo = TRUE) THEN
        SELECT 'ERROR: Ya existe un evento programado en ese lugar para esa fecha' AS mensaje;
    ELSE
        INSERT INTO eventos (nombre_evento, fecha_evento, lugar, activo) VALUES (p_nombre, p_fecha, p_lugar, TRUE);
        SELECT 'ÉXITO: Evento creado' AS mensaje;
    END IF;
END //

-- ELIMINAR EVENTO
CREATE PROCEDURE EliminarEvento(IN p_id_evento INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; SELECT 'ERROR: Fallo al eliminar' AS mensaje; END;
    START TRANSACTION;
        DELETE FROM evaluaciones WHERE id_equipo IN (SELECT id_equipo FROM equipos WHERE id_evento = p_id_evento);
        DELETE FROM integrantes WHERE id_equipo IN (SELECT id_equipo FROM equipos WHERE id_evento = p_id_evento);
        DELETE FROM jueces_eventos WHERE id_evento = p_id_evento;
        DELETE FROM equipos WHERE id_evento = p_id_evento;
        DELETE FROM eventos WHERE id_evento = p_id_evento;
    COMMIT;
    SELECT 'ÉXITO: Evento eliminado' AS mensaje;
END //

-- ASIGNAR JUEZ
CREATE PROCEDURE AsignarJuezEvento(IN p_id_evento INT, IN p_id_juez INT, IN p_id_categoria INT)
BEGIN
    DECLARE v_escuela_juez VARCHAR(150);
    SELECT escuela_proc INTO v_escuela_juez FROM usuarios WHERE id_usuario = p_id_juez;
    
    IF (SELECT COUNT(*) FROM jueces_eventos WHERE id_evento = p_id_evento AND id_categoria = p_id_categoria) >= 3 THEN
        SELECT 'ERROR: Límite de 3 jueces alcanzado' AS mensaje;
    ELSEIF EXISTS (SELECT 1 FROM jueces_eventos WHERE id_evento=p_id_evento AND id_juez=p_id_juez AND id_categoria=p_id_categoria) THEN
        SELECT 'ADVERTENCIA: Juez ya asignado' AS mensaje;
    ELSEIF EXISTS (SELECT 1 FROM equipos WHERE id_coach = p_id_juez AND id_evento = p_id_evento AND id_categoria = p_id_categoria) THEN
        SELECT 'ERROR: Conflicto de interés (Tiene equipo propio)' AS mensaje;
    ELSEIF EXISTS (SELECT 1 FROM equipos WHERE escuela_procedencia = v_escuela_juez AND id_evento = p_id_evento AND id_categoria = p_id_categoria) THEN
        SELECT 'ERROR: Conflicto de interés (Misma escuela)' AS mensaje;
    ELSE
        INSERT INTO jueces_eventos(id_evento, id_juez, id_categoria) VALUES(p_id_evento, p_id_juez, p_id_categoria);
        SELECT 'ÉXITO: Juez asignado' AS mensaje;
    END IF;
END //

-- QUITAR JUEZ DE EVENTO
CREATE PROCEDURE QuitarJuezEvento(IN p_id_evento INT, IN p_id_juez INT, IN p_id_categoria INT)
BEGIN
    DELETE FROM jueces_eventos WHERE id_evento = p_id_evento AND id_juez = p_id_juez AND id_categoria = p_id_categoria;
END //

-- REGISTRAR EVALUACION
CREATE PROCEDURE RegistrarEvaluacion(
    IN p_id_equipo INT, IN p_id_juez INT, IN p_total INT, IN p_detalles JSON
)
BEGIN
    DECLARE v_existe INT;
    SELECT COUNT(*) INTO v_existe FROM evaluaciones WHERE id_equipo = p_id_equipo;

    IF v_existe > 0 THEN
        UPDATE evaluaciones 
        SET puntuacion_total = p_total, id_juez = p_id_juez, detalles_evaluacion = p_detalles, fecha_evaluacion = NOW()
        WHERE id_equipo = p_id_equipo;
        SELECT 'ÉXITO: Evaluación actualizada correctamente.' AS mensaje;
    ELSE
        INSERT INTO evaluaciones(id_equipo, id_juez, puntuacion_total, detalles_evaluacion)
        VALUES(p_id_equipo, p_id_juez, p_total, p_detalles);
        UPDATE equipos SET estado_proyecto = 'EVALUADO' WHERE id_equipo = p_id_equipo;
        SELECT 'ÉXITO: Evaluación registrada correctamente.' AS mensaje;
    END IF;
END //

-- CONSULTAS DE LISTADO (Modificado para recibir id_coach en ListarIntegrantesPorEquipo)
CREATE PROCEDURE ListarDetalleEquiposPorCoach(IN p_id_coach INT)
BEGIN
    SELECT e.id_equipo, e.nombre_equipo, e.nombre_prototipo, ev.nombre_evento, c.nombre_categoria, e.estado_proyecto,
           (SELECT COUNT(*) FROM integrantes i WHERE i.id_equipo = e.id_equipo) as total_integrantes
    FROM equipos e
    JOIN eventos ev ON e.id_evento = ev.id_evento
    JOIN categorias c ON e.id_categoria = c.id_categoria
    WHERE e.id_coach = p_id_coach AND e.activo = TRUE
    ORDER BY e.id_equipo DESC;
END //

-- MODIFICADO: Ahora valida la propiedad del equipo mediante un JOIN
CREATE PROCEDURE ListarIntegrantesPorEquipo(IN p_id_equipo INT, IN p_id_coach INT)
BEGIN
    SELECT i.id_integrante, i.nombre_completo, i.edad, i.grado, i.escuela 
    FROM integrantes i
    INNER JOIN equipos e ON i.id_equipo = e.id_equipo
    WHERE i.id_equipo = p_id_equipo AND e.id_coach = p_id_coach;
END //

CREATE PROCEDURE Sp_AdminListarEventos()
BEGIN
    SELECT id_evento, nombre_evento, fecha_evento, lugar FROM eventos ORDER BY fecha_evento DESC;
END //

CREATE PROCEDURE ListarJuecesDisponibles()
BEGIN
    SELECT id_usuario, CONCAT(nombres, ' ', apellidos) as nombre_completo 
    FROM usuarios WHERE (tipo_usuario = 'JUEZ' OR tipo_usuario = 'COACH_JUEZ') AND activo = TRUE;
END //

CREATE PROCEDURE Sp_ListarJuecesDeEvento(IN p_id_evento INT)
BEGIN
    SELECT je.id_evento, u.id_usuario, u.nombres, u.apellidos, u.escuela_proc, c.id_categoria, c.nombre_categoria 
    FROM jueces_eventos je 
    JOIN usuarios u ON je.id_juez = u.id_usuario 
    JOIN categorias c ON je.id_categoria = c.id_categoria 
    WHERE je.id_evento = p_id_evento ORDER BY c.nombre_categoria;
END //

CREATE PROCEDURE Sp_Juez_ObtenerCategoriasAsignadas(IN p_id_juez INT)
BEGIN
    SELECT DISTINCT c.nombre_categoria FROM jueces_eventos je JOIN categorias c ON je.id_categoria = c.id_categoria WHERE je.id_juez = p_id_juez;
END //

CREATE PROCEDURE Sp_Juez_ListarProyectos(IN p_id_juez INT, IN p_nombre_categoria VARCHAR(50))
BEGIN
    DECLARE v_escuela_juez VARCHAR(150);
    SELECT escuela_proc INTO v_escuela_juez FROM usuarios WHERE id_usuario = p_id_juez;

    SELECT e.id_equipo, e.nombre_equipo, e.nombre_prototipo, e.estado_proyecto
    FROM equipos e
    JOIN categorias c ON e.id_categoria = c.id_categoria
    JOIN jueces_eventos je ON e.id_evento = je.id_evento AND e.id_categoria = je.id_categoria
    WHERE je.id_juez = p_id_juez AND c.nombre_categoria = p_nombre_categoria AND e.activo = TRUE
      AND (SELECT COUNT(*) FROM integrantes i WHERE i.id_equipo = e.id_equipo) = 3
      AND e.escuela_procedencia <> v_escuela_juez
      AND e.id_coach <> p_id_juez
    ORDER BY FIELD(e.estado_proyecto, 'PENDIENTE', 'EVALUADO'), e.nombre_equipo;
END //

CREATE PROCEDURE Sp_Admin_ListarUsuariosCandidatos()
BEGIN
    SET SESSION group_concat_max_len = 10000;
    SELECT u.id_usuario, u.nombres, u.apellidos, u.email, u.escuela_proc, u.tipo_usuario,
        (SELECT GROUP_CONCAT(DISTINCT c.nombre_categoria SEPARATOR ', ') FROM equipos e JOIN categorias c ON e.id_categoria = c.id_categoria WHERE e.id_coach = u.id_usuario AND e.activo = 1) as categorias_equipos,
        (SELECT GROUP_CONCAT(DISTINCT c.nombre_categoria SEPARATOR ', ') FROM jueces_eventos je JOIN categorias c ON je.id_categoria = c.id_categoria WHERE je.id_juez = u.id_usuario) as categorias_juez
    FROM usuarios u 
    WHERE (u.tipo_usuario = 'COACH' OR u.tipo_usuario = 'COACH_JUEZ' OR u.tipo_usuario = 'JUEZ') AND u.activo = 1 
    ORDER BY u.nombres ASC;
END //

CREATE PROCEDURE Sp_AdminListarEventosActivos()
BEGIN SELECT id_evento, nombre_evento FROM eventos WHERE activo = 1 ORDER BY fecha_evento DESC; END //

CREATE PROCEDURE Sp_AdminListarCategorias()
BEGIN SELECT id_categoria, nombre_categoria FROM categorias ORDER BY id_categoria ASC; END //

CREATE PROCEDURE Sp_ObtenerDetalleEvaluacion(IN p_id_equipo INT)
BEGIN
    SELECT e.puntuacion_total, e.detalles_evaluacion, e.fecha_evaluacion, 
           CONCAT(u.nombres, ' ', u.apellidos) as nombre_juez
    FROM evaluaciones e
    JOIN usuarios u ON e.id_juez = u.id_usuario
    WHERE e.id_equipo = p_id_equipo;
END //

DELIMITER ;

DELIMITER //

-- =============================================
-- REPORTES ADMINISTRADOR
-- =============================================

-- 1. Reporte de los 3 primeros lugares (Top 3)

CREATE PROCEDURE Sp_Reporte_Top3(IN p_id_evento INT, IN p_id_categoria INT)
BEGIN
    SELECT 
        e.nombre_equipo,
        e.nombre_prototipo,
        e.escuela_procedencia,
        COALESCE(ev.puntuacion_total, 0) as puntaje
    FROM equipos e
    JOIN evaluaciones ev ON e.id_equipo = ev.id_equipo
    WHERE e.id_evento = p_id_evento 
      AND e.id_categoria = p_id_categoria
      AND e.estado_proyecto = 'EVALUADO'
      AND e.activo = 1
    ORDER BY ev.puntuacion_total DESC
    LIMIT 3;
END //

-- 2. Lista de Equipos por Categoría
CREATE PROCEDURE Sp_Reporte_EquiposPorCategoria(IN p_id_evento INT, IN p_id_categoria INT)
BEGIN
    SELECT 
        e.nombre_equipo,
        e.escuela_procedencia,
        u.nombres as nombre_coach,
        u.apellidos as apellido_coach,
        e.estado_proyecto
    FROM equipos e
    JOIN usuarios u ON e.id_coach = u.id_usuario
    WHERE e.id_evento = p_id_evento 
      AND e.id_categoria = p_id_categoria
      AND e.activo = 1
    ORDER BY e.nombre_equipo ASC;
END //

-- 3. Cantidad de Equipos por Evento (Estadísticas Generales)
CREATE PROCEDURE Sp_Reporte_ConteoPorEvento()
BEGIN
    SELECT 
        ev.nombre_evento,
        COUNT(e.id_equipo) as total_equipos,
        SUM(CASE WHEN e.estado_proyecto = 'EVALUADO' THEN 1 ELSE 0 END) as equipos_evaluados
    FROM eventos ev
    LEFT JOIN equipos e ON ev.id_evento = e.id_evento AND e.activo = 1
    WHERE ev.activo = 1
    GROUP BY ev.id_evento
    ORDER BY ev.fecha_evento DESC;
END //

-- =============================================
-- REPORTES GENERALES (COACH / JUEZ)
-- =============================================

-- 4. Tabla de Puntaje Global (Ranking completo sin límite)
CREATE PROCEDURE Sp_Reporte_TablaGlobal(IN p_id_evento INT, IN p_id_categoria INT)
BEGIN
    SELECT 
        e.nombre_equipo,
        e.escuela_procedencia,
        CASE 
            WHEN e.estado_proyecto = 'EVALUADO' THEN ev.puntuacion_total 
            ELSE 'N/A' 
        END as puntaje_final,
        e.estado_proyecto
    FROM equipos e
    LEFT JOIN evaluaciones ev ON e.id_equipo = ev.id_equipo
    WHERE e.id_evento = p_id_evento 
      AND e.id_categoria = p_id_categoria
      AND e.activo = 1
    ORDER BY (ev.puntuacion_total IS NULL), ev.puntuacion_total DESC; 
END //

-- 5. Detalle de Evaluación (Para el Coach - Ver su propio equipo)
-- Nota: Reutilizamos o mejoramos Sp_ObtenerDetalleEvaluacion
CREATE PROCEDURE Sp_Reporte_DetalleMiEquipo(IN p_id_equipo INT, IN p_id_coach INT)
BEGIN
    -- Validamos que el equipo pertenezca al coach por seguridad
    IF EXISTS (SELECT 1 FROM equipos WHERE id_equipo = p_id_equipo AND id_coach = p_id_coach) THEN
        SELECT 
            e.nombre_equipo,
            ev.puntuacion_total,
            ev.detalles_evaluacion, -- JSON con los criterios
            ev.fecha_evaluacion,
            CONCAT(j.nombres, ' ', j.apellidos) as nombre_juez
        FROM evaluaciones ev
        JOIN equipos e ON ev.id_equipo = e.id_equipo
        JOIN usuarios j ON ev.id_juez = j.id_usuario
        WHERE e.id_equipo = p_id_equipo;
    ELSE
        SELECT 'ERROR' as resultado;
    END IF;
END //

DELIMITER ;

DELIMITER //

-- =========================================================
--       1. REPORTES ADMINISTRADOR (Métricas Globales)
-- =========================================================

-- A. Top 3 primeros lugares por puntaje
DROP PROCEDURE IF EXISTS Sp_Reporte_Top3 //
CREATE PROCEDURE Sp_Reporte_Top3(IN p_id_evento INT, IN p_id_categoria INT)
BEGIN
    SELECT 
        e.nombre_equipo,
        e.nombre_prototipo,
        e.escuela_procedencia,
        COALESCE(ev.puntuacion_total, 0) as puntaje
    FROM equipos e
    JOIN evaluaciones ev ON e.id_equipo = ev.id_equipo
    WHERE e.id_evento = p_id_evento 
      AND e.id_categoria = p_id_categoria
      AND e.estado_proyecto = 'EVALUADO'
      AND e.activo = 1
    ORDER BY ev.puntuacion_total DESC
    LIMIT 3;
END //

-- B. Lista de todos los equipos en una categoría
DROP PROCEDURE IF EXISTS Sp_Reporte_EquiposPorCategoria //
CREATE PROCEDURE Sp_Reporte_EquiposPorCategoria(IN p_id_evento INT, IN p_id_categoria INT)
BEGIN
    SELECT 
        e.nombre_equipo,
        e.escuela_procedencia,
        CONCAT(u.nombres, ' ', u.apellidos) as nombre_coach,
        e.estado_proyecto
    FROM equipos e
    JOIN usuarios u ON e.id_coach = u.id_usuario
    WHERE e.id_evento = p_id_evento 
      AND e.id_categoria = p_id_categoria
      AND e.activo = 1
    ORDER BY e.nombre_equipo ASC;
END //

-- C. Estadística: Cantidad de equipos por evento
DROP PROCEDURE IF EXISTS Sp_Reporte_ConteoPorEvento //
CREATE PROCEDURE Sp_Reporte_ConteoPorEvento()
BEGIN
    SELECT 
        ev.nombre_evento,
        COUNT(e.id_equipo) as total_equipos,
        SUM(CASE WHEN e.estado_proyecto = 'EVALUADO' THEN 1 ELSE 0 END) as equipos_evaluados
    FROM eventos ev
    LEFT JOIN equipos e ON ev.id_evento = e.id_evento AND e.activo = 1
    WHERE ev.activo = 1
    GROUP BY ev.id_evento
    ORDER BY ev.fecha_evento DESC;
END //

-- =========================================================
--       2. REPORTES GENERALES (Tabla Global)
-- =========================================================

-- D. Tabla de posiciones completa (Para Coach y Juez)
DROP PROCEDURE IF EXISTS Sp_Reporte_TablaGlobal //
CREATE PROCEDURE Sp_Reporte_TablaGlobal(IN p_id_evento INT, IN p_id_categoria INT)
BEGIN
    SELECT 
        e.nombre_equipo,
        e.escuela_procedencia,
        CASE 
            WHEN e.estado_proyecto = 'EVALUADO' THEN ev.puntuacion_total 
            ELSE 'N/A' 
        END as puntaje_final,
        e.estado_proyecto
    FROM equipos e
    LEFT JOIN evaluaciones ev ON e.id_equipo = ev.id_equipo
    WHERE e.id_evento = p_id_evento 
      AND e.id_categoria = p_id_categoria
      AND e.activo = 1
    ORDER BY (ev.puntuacion_total IS NULL), ev.puntuacion_total DESC; 
END //

-- =========================================================
--       3. HERRAMIENTAS PARA COACH (Desglose)
-- =========================================================

-- E. [CORRECCIÓN] Listar mis equipos ya evaluados (Para el combo)
DROP PROCEDURE IF EXISTS Sp_Coach_ListarMisEquiposEvaluados //
CREATE PROCEDURE Sp_Coach_ListarMisEquiposEvaluados(IN p_id_coach INT)
BEGIN
    SELECT id_equipo, nombre_equipo 
    FROM equipos 
    WHERE id_coach = p_id_coach AND estado_proyecto = 'EVALUADO' AND activo = 1;
END //

-- F. Ver el desglose detallado de mi calificación
DROP PROCEDURE IF EXISTS Sp_Reporte_DetalleMiEquipo //
CREATE PROCEDURE Sp_Reporte_DetalleMiEquipo(IN p_id_equipo INT, IN p_id_coach INT)
BEGIN
    -- Validamos propiedad por seguridad
    IF EXISTS (SELECT 1 FROM equipos WHERE id_equipo = p_id_equipo AND id_coach = p_id_coach) THEN
        SELECT 
            e.nombre_equipo,
            ev.puntuacion_total,
            ev.detalles_evaluacion, -- JSON
            ev.fecha_evaluacion,
            CONCAT(j.nombres, ' ', j.apellidos) as nombre_juez
        FROM evaluaciones ev
        JOIN equipos e ON ev.id_equipo = e.id_equipo
        JOIN usuarios j ON ev.id_juez = j.id_usuario
        WHERE e.id_equipo = p_id_equipo;
    ELSE
        SELECT 'ERROR' as resultado;
    END IF;
END //

DELIMITER ;