DELIMITER //
-- stored procedure : registrar cliente premium

-- 1 cliente = 5000 en un mes
-- clientes con 'Smartphone' y precio 0
-- límite máximo clientes mes
-- registrar en usuarios y clientes, pedido por defecto 'Smartphone' 0

CREATE PROCEDURE registrar_cliente_premium(
    -- parámetros entrada cliente y usuario -- NO IDs, sólo tipos
    -- IN parámetro TipoParámetro
    IN p_email VARCHAR(255),
    IN p_contraseña VARCHAR(255),
    IN p_nombre VARCHAR(255),
    IN p_direccionEnvio VARCHAR(255),
    IN p_codigoPostal VARCHAR(10),
    IN p_fechaNacimiento DATE
)
BEGIN
    -- declara parámetros a usar: IDs, otros
    -- DECLARE parámetro TipoParámetro
    DECLARE p_usuarioId INT;
    DECLARE p_clienteId INT;
    DECLARE facturacionTotal INT;
    DECLARE nClientesPremium INT;
    DECLARE max INT;
    DECLARE p_pedidoId INT;
    DECLARE p_productoId INT;

    -- errores
    -- rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente premium no creado';
    END;


    -- inicio transacción
    START TRANSACTION;

    -- calcular parámetros nuevos
    -- SELECT INTO FROM WHERE ...
    -- facturacion total: pedidos mes anterior
    SELECT SUM(LineasPedido.precio * LineasPedido.unidades)
    INTO facturacionTotal
    FROM Pedidos
        JOIN LineasPedido ON LineasPedido.pedidoId = Pedidos.id
    WHERE 
        MONTH(Pedidos.fechaRealizacion) +1 = MONTH(CURDATE())
        AND 
        YEAR(Pedidos.fechaRealizacion) = YEAR(CURDATE());
    IF v_facturacionTotal IS NULL THEN -- si no hay facturación
      SET v_facturacionTotal = 0;
    END IF;
    -- nClientesPremium
    SELECT COUNT(DISTINCT Pedidos.clienteId)
    INTO nClientesPremium
    FROM Pedidos
        JOIN LineasPedido ON LineasPedido.pedidoId = Pedidos.id
        JOIN Productos ON Productos.id = LineasPedido.productoId
    WHERE 
        LineasPedido.precio=0 AND Productos.nombre='Smartphone'
        AND
        MONTH(Pedidos.fechaRealizacion) = MONTH(CURDATE()) AND YEAR(Pedidos.fechaRealizacion) = YEAR(CURDATE());

    -- errores
    -- si se supera el max
    IF nClientesPremium >= max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'no se pueden añadir más clientes premium';
    END IF;

    -- crear cliente premium
    -- tabla usuarios
    INSERT INTO Usuarios(email, contraseña, nombre) VALUES
        (p_email, p_contraseña, p_nombre);
    SET p_usuarioId = LAST_INSERT_ID();
    -- tabla clientes
    INSERT INTO Clientes(usuarioId, direccionEnvio, codigoPostal, fechaNacimiento) VALUES
        (p_usuarioId, p_direccionEnvio, p_codigoPostal, p_fechaNacimiento);
    SET p_clienteId = LAST_INSERT_ID();
    -- tabla pedidos
    INSERT INTO Pedidos(fechaRealizacion, direccionEntrega, clienteId) VALUES
        (CURDATE(), p_direccionEnvio, p_clienteId);
    SET p_pedidoId = LAST_INSERT_ID();
    -- tabla linea pedidos
    SELECT Productos.id
    INTO p_productoId
    FROM Productos
    WHERE Productos.nombre = 'Smartphone';

    INSERT INTO LineasPedido(pedidoId, productoId, unidades, precio) VALUES
        (p_pedidoId, p_productoId, 1, 0);

    -- fin transacción
    COMMIT;
END//

-- trigger : cantidad max pedidos
CREATE OR REPLACE TRIGGER limitar_cantidad_por_cliente 
BEFORE INSERT ON LineasPedido
FOR EACH ROW
BEGIN
    -- declara parámetros a usar
    -- DECLARE parámetro TipoParámetro (DEFAULT)
    DECLARE unidadesMax INT DEFAULT 200;
    DECLARE mediaUnidadesPedido DECIMAL(10,2) DEFAULT 0.0;
    DECLARE totalPedidos INT DEFAULT 0;
    DECLARE clienteId INT DEFAULT NULL;
    DECLARE cantidadTotal INT DEFAULT 0;
    DECLARE mensajeError TEXT;

    -- valores
    -- cliente
    SELECT p.clienteId INTO clienteId
    FROM Pedidos p
    WHERE p.id = NEW.pedidoId;
    IF clienteId IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El pedido no está asociado a un cliente válido.';
    END IF;
    -- total pedidos
    SELECT COUNT(*)
    INTO totalPedidos
    FROM Pedidos
    WHERE Pedidos.clienteId = clienteId;
    -- datos antiguos
    IF totalPedidos>=10 THEN
        -- media unidades
        SELECT SUM(LineasPedido.unidades)/COUNT(Pedidos.id)
        INTO mediaUnidadesPedido
        FROM Pedidos
            JOIN LineasPedido ON LineasPedido.pedidoId = Pedidos.clienteId
        WHERE Pedidos.clienteId = clienteId;
        -- unidadesMax
        IF mediaUnidadesPedido>0 THEN
            SET unidadesMax = mediaUnidadesPedido*2;
        ELSE
            SET unidadesMax = 200;
        END IF;
    ELSE 
        SET unidadesMax = 200
    END IF;
    -- datos actualizados
    -- cantidad total
    SELECT SUM(LineasPedido.unidades)
    INTO cantidadTotal
    FROM LineasPedido
    WHERE LineasPedido.pedidoId = NEW.pedidoId;
    SET cantidadTotal = cantidadTotal + NEW.unidades;

    -- errores
    IF cantidadTotal = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = mensajeError;
    END IF;
    IF cantidadTotal > unidadesMax THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = mensajeError;
    END IF;
END//

-- funcion fidelidad
CREATE FUNCTION calcular_fidelidad_cliente(
    clienteId INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    -- declara parámetros
    DECLARE nPedidos INT;
    DECLARE gasto DECIMAL(10,2);
    DECLARE fidelidad DECIMAL(10,2);

    -- valores
    -- nPedidos
    SELECT COUNT(*)
    INTO nPedidos
    FROM Pedidos
    WHERE Pedidos.clienteId = clienteId;
    -- gasto
    SELECT SUM(LineasPedido.unidades*LineasPedido.precio)
    INTO gasto
    FROM LineasPedido
        JOIN Pedidos ON Pedidos.id = LineasPedido.pedidoId
    WHERE Pedidos.clienteId = clienteId;
    -- fidelidad
    SET fidelidad = (nPedidos*0.5)+(gasto*0.05);

    -- return
    RETURN fidelidad;
END//

-- vista
CREATE OR REPLACE VIEW VistaPedidosFidelidad AS
SELECT
    Clientes.id AS clienteId,
    Usuarios.nombre AS nombreCliente,
    Usuarios.email AS emailCliente,
    COUNT(DISTINCT Pedidos.id) AS pedidosUltimoMes,
    SUM(LineasPedido.unidades*LineasPedido.precio) AS facturacionUltimoMes,
    calcular_fidelidad_cliente(Pedidos.clienteId) AS indiceFidelidad
FROM Usuarios
    JOIN Clientes ON Usuarios.id = Clientes.usuarioId
    JOIN Pedidos ON 
        Pedidos.clienteId = Clientes.id 
        AND
        MONTH(Pedidos.fechaRealizacion) + 1 = MONTH(CURDATE());
    JOIN LineasPedido ON Pedidos.id = LineasPedido.pedidoId
GROUP BY Clientes.id, Usuarios.nombre, Usuarios.email;
END //

DELIMITER ;
