-- stored procedure : registrar cliente premium

-- 1 cliente = 5000 en un mes
-- cleintes con 'Smartphone' y precio 0
-- límite máximo clientes mes
-- registrar en usuarios y clientes, pedido por defecto 'Smartphone' 0

DELIMITER //
CREATE PROCEDURE registrar_cliente_premium(
    -- parámetros entrada cliente y usuario -- NO IDs, sólo tipos
    -- IN parámetro TipoParámetro
    IN email VARCHAR(255),
    IN contraseña VARCHAR(255),
    IN nombre VARCHAR(255),
    IN direccionEnvio VARCHAR(255),
    IN codigoPostal VARCHAR(10),
    IN fechaNacimiento DATE
)
    BEGIN
    -- declara parámetros a usar: IDs, otros
    -- DECLARE parámetro TipoParámetro
    DECLARE usuarioId INT,
    DECLARE facturacionTotal INT
    DECLARE nClientesPremium INT,
    DECLARE max INT
    DECLARE productoId INT,
    DECLARE precio INT

    -- errores
    -- si se supera el max

    -- crear cliente premium
    -- tabla clientes
    -- tabla usuarios
    -- tabla pedidos

    END//
DELIMITER ;
