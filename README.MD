# Lab5: SQL Avanzado

Parta del archivo `1.creacionTablas.sql` para crear la base de datos tiendaOnline y ejecute el archivo `2.popularBD.sql` para insertar datos de prueba para comenzar con el laboratorio y realice los siguientes ejercicios.

## 1. Stored Procedure - Registrar cliente *premium*
Diseñe un stored procedure llamado `registrar_cliente_premium` que permita registrar un cliente *premium* cumpliendo las siguientes condiciones:

1. Se podrá registrar un cliente *premium* por cada **5000 euros de facturación total** de la empresa en pedidos del mes anterior al de la creación del cliente premium. Es decir, si hemos facturado 12.000 € en septiembre, en octubre solo podremos registrar 2 clientes *premium*.

2. Para contabilizar el número de clientes premium registrados este mes, se considerarán aquellos clientes que tienen un pedido con una línea de pedido que contenga el producto `'Smartphone'` y cuyo precio sea `0`.

3. Se debe controlar un **límite máximo de clientes premium por mes**:
   - Si al registrar un nuevo cliente premium se superaría el límite mensual, se debe impedir el registro y lanzar una excepción con el mensaje:
     `"Límite de clientes premium alcanzado"`.

4. Si se cumple que se pueden crear clientes premium:
   - El cliente premium será registrado como un cliente normal en las tablas `Usuarios` y `Clientes`.
   - Se generará un **pedido por defecto** para este cliente que contendrá una única línea de pedido:
     - Producto: `'Smartphone'`.
     - Precio: `0`.

## Instrucciones
1. Implementa el stored procedure `registrar_cliente_premium`.
2. Asegúrate de verificar las condiciones de facturación y el límite de clientes premium antes de registrar al cliente.
3. Usa transacciones para garantizar que todas las operaciones se realicen de manera consistente.
4. Introduzca los datos necesarios para probar casos positivos como negativos de su solución.

## Ejemplo de uso
```sql
CALL registrar_cliente_premium('email@domain.com', 'password123', 'Nombre Cliente', 'Dirección Cliente', '12345', '1990-01-01');
```
<details>
<summary><b>Solución</b></summary>

  ```sql
   DELIMITER //

CREATE PROCEDURE registrar_cliente_premium(
    IN p_email VARCHAR(255),
    IN p_contrasena VARCHAR(255),
    IN p_nombre VARCHAR(255),
    IN p_direccionEnvio VARCHAR(255),
    IN p_codigoPostal VARCHAR(10),
    IN p_fechaNacimiento DATE
)
BEGIN
    DECLARE v_usuarioId INT;
    DECLARE v_clienteId INT;
    DECLARE v_pedidoId INT;
    DECLARE v_smartphoneId INT;
    DECLARE v_facturacionTotal DECIMAL(10, 2);
    DECLARE v_clientesPremiumPermitidos INT;
    DECLARE v_clientesPremiumRegistrados INT;

    -- Manejo de errores
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error al registrar cliente premium';
    END;

    -- Iniciar transacción
    START TRANSACTION;

    -- Calcular la facturación total del mes anterior
    SELECT SUM(lp.precio * lp.unidades)
    INTO v_facturacionTotal
    FROM LineasPedido lp
    JOIN Pedidos p ON lp.pedidoId = p.id
    WHERE MONTH(p.fechaRealizacion) = MONTH(CURDATE()) - 1
    AND YEAR(p.fechaRealizacion) = YEAR(CURDATE());

    IF v_facturacionTotal IS NULL THEN
        SET v_facturacionTotal = 0; -- Si no hay facturación, se considera 0.
    END IF;

    -- Calcular cuántos clientes premium están permitidos
    SET v_clientesPremiumPermitidos = FLOOR(v_facturacionTotal / 5000);

    -- Contar cuántos clientes premium se han registrado este mes
    SELECT COUNT(DISTINCT p.clienteId)
    INTO v_clientesPremiumRegistrados
    FROM Pedidos p
    JOIN LineasPedido lp ON p.id = lp.pedidoId
    JOIN Productos prod ON lp.productoId = prod.id
    WHERE prod.nombre = 'Smartphone' AND lp.precio = 0
    AND MONTH(p.fechaRealizacion) = MONTH(CURDATE())
    AND YEAR(p.fechaRealizacion) = YEAR(CURDATE());

    -- Verificar si se ha alcanzado el límite de clientes premium
    IF v_clientesPremiumRegistrados >= v_clientesPremiumPermitidos THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Límite de clientes premium alcanzado';
    END IF;

    -- Crear el usuario
    INSERT INTO Usuarios (email, contraseña, nombre)
    VALUES (p_email, p_contrasena, p_nombre);

    SET v_usuarioId = LAST_INSERT_ID();

    -- Crear el cliente
    INSERT INTO Clientes (usuarioId, direccionEnvio, codigoPostal, fechaNacimiento)
    VALUES (v_usuarioId, p_direccionEnvio, p_codigoPostal, p_fechaNacimiento);

    SET v_clienteId = LAST_INSERT_ID();

    -- Obtener el ID del producto "Smartphone"
    SELECT id INTO v_smartphoneId
    FROM Productos
    WHERE nombre = 'Smartphone';

    IF v_smartphoneId IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El producto "Smartphone" no existe';
    END IF;

    -- Crear el pedido por defecto
    INSERT INTO Pedidos (clienteId, direccionEntrega, fechaRealizacion)
    VALUES (v_clienteId, p_direccionEnvio, CURDATE());

    SET v_pedidoId = LAST_INSERT_ID();

    -- Insertar la línea de pedido con precio 0
    INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
    VALUES (v_pedidoId, v_smartphoneId, 1, 0);

    -- Confirmar transacción
    COMMIT;
END//

DELIMITER ;

  ```
</details>

<details>
<summary><b>Datos de prueba</b></summary>

  ```sql
    INSERT INTO Usuarios (email, contraseña, nombre)
VALUES 
('cliente1@example.com', 'password123', 'Cliente Uno'),
('cliente2@example.com', 'password123', 'Cliente Dos'),
('cliente3@example.com', 'password123', 'Cliente Tres');

INSERT INTO Clientes (usuarioId, direccionEnvio, codigoPostal, fechaNacimiento)
VALUES 
(1, 'Calle A, 123', '41001', '1990-05-10'),
(2, 'Calle B, 456', '41002', '1985-08-20'),
(3, 'Calle C, 789', '41003', '2000-12-15');

INSERT INTO Productos (nombre, descripción, precio, tipoProductoId, puedeVenderseAMenores)
VALUES 
('Smartphone', 'Un teléfono inteligente', 800.00, 1, FALSE),
('Auriculares', 'Auriculares Bluetooth', 150.00, 2, TRUE),
('Cargador', 'Cargador rápido USB-C', 50.00, 2, TRUE);

-- Pedidos de Cliente 1 en el mes anterior
INSERT INTO Pedidos (fechaRealizacion, fechaEnvio, direccionEntrega, clienteId)
VALUES 
(DATE_SUB(CURDATE(), INTERVAL 1 MONTH), DATE_SUB(CURDATE(), INTERVAL 25 DAY), 'Calle A, 123', 1),
(DATE_SUB(CURDATE(), INTERVAL 1 MONTH), DATE_SUB(CURDATE(), INTERVAL 20 DAY), 'Calle A, 123', 1);

-- Pedidos de Cliente 2 en el mes anterior
INSERT INTO Pedidos (fechaRealizacion, fechaEnvio, direccionEntrega, clienteId)
VALUES 
(DATE_SUB(CURDATE(), INTERVAL 1 MONTH), DATE_SUB(CURDATE(), INTERVAL 28 DAY), 'Calle B, 456', 2);

-- Líneas de Pedido para Cliente 1
INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES 
(1, 1, 2, 800.00), -- Smartphone x2
(1, 3, 1, 50.00),  -- Cargador x1
(2, 2, 3, 150.00); -- Auriculares x3

-- Líneas de Pedido para Cliente 2
INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES 
(3, 1, 1, 800.00), -- Smartphone x1
(3, 2, 2, 150.00); -- Auriculares x2

  ```
Con estos datos, la llamada al stored procedure con esta sentencia debería fallar, al haber facturado 3200€, ya que se necesitan al menos 5000€ de facturación en el mes anterior para poder registrar un cliente *premium*. Compruébelo haciendo una llamada al ```stored_procedure```.
```sql
CALL registrar_cliente_premium(
    'premium1@example.com',
    'password123',
    'Cliente Premium Uno',
    'Calle Premium, 1',
    '41004',
    '1988-07-25'
);
```
Para probar un caso positivo, habrá que incrementar la facturación del mes anterior:
```sql
-- Incrementar facturación para Cliente 1
INSERT INTO Pedidos (fechaRealizacion, fechaEnvio, direccionEntrega, clienteId)
VALUES (DATE_SUB(CURDATE(), INTERVAL 1 MONTH), DATE_SUB(CURDATE(), INTERVAL 15 DAY), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (4, 1, 4, 800.00); -- Smartphone x4 (3200 € adicionales)

```
Y, ahora que se ha facturado 6400€ el mes anterior, debería permitir registrar 1 cliente *premium*.
```sql
CALL registrar_cliente_premium(
    'premium1@example.com',
    'password123',
    'Cliente Premium Uno',
    'Calle Premium, 1',
    '41004',
    '1988-07-25'
);
```
Recuerde que puede vaciar todas las tablas truncándolas, y puede ignorar la comprobación de foreign keys con ```SET_FOREIGN_KEY_CHECKS```:
```sql
SET FOREIGN_KEY_CHECKS=0;
TRUNCATE TABLE pedidos;
TRUNCATE TABLE clientes;
TRUNCATE TABLE empleados;
TRUNCATE TABLE lineaspedido;
TRUNCATE TABLE productos;
TRUNCATE TABLE tiposproducto;
TRUNCATE TABLE usuarios;
SET FOREIGN_KEY_CHECKS=0;
```
</details>

## 2. Trigger - Cantidad máxima de Pedidos
Diseña un trigger llamado `limitar_cantidad_por_cliente` que imponga un límite dinámico en la cantidad total de unidades permitidas en un pedido. El límite dependerá del historial de compras del cliente:

1. Si el cliente tiene **menos de 10 pedidos**, el límite será fijo: **200 unidades por pedido**.
2. Si el cliente tiene **10 o más pedidos**, el límite será el doble de la **media de unidades por pedido** de ese cliente.

El trigger debe ejecutarse **antes de insertar una nueva línea de pedido** en la tabla `LineasPedido`. Si la cantidad total de unidades del pedido supera el límite calculado para el cliente, se debe lanzar un error con un mensaje adecuado.

Inserte los datos que considere adecuados para probar que el trigger se comporta adecuadamente.


<details>
<summary><b>Solución</b></summary>

```sql
DELIMITER //

CREATE OR REPLACE TRIGGER limitar_cantidad_por_cliente BEFORE INSERT ON LineasPedido
FOR EACH ROW
BEGIN
    DECLARE clienteId INT DEFAULT NULL;
    DECLARE totalPedidos INT DEFAULT 0;
    DECLARE mediaUnidadesPorPedido DECIMAL(10, 2) DEFAULT 0.0;
    DECLARE limiteUnidades INT DEFAULT 200;
    DECLARE cantidadTotal INT DEFAULT 0;
    DECLARE mensajeError TEXT;

    -- Obtener el cliente asociado al pedido
    SELECT p.clienteId INTO clienteId
    FROM Pedidos p
    WHERE p.id = NEW.pedidoId;

    -- Validar si el cliente asociado al pedido existe
    IF clienteId IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El pedido no está asociado a un cliente válido.';
    END IF;

    -- Contar el número de pedidos realizados por el cliente
    SELECT COUNT(*) INTO totalPedidos
    FROM Pedidos
    WHERE clienteId = clienteId;

    -- Validar si el cliente tiene pedidos
    IF totalPedidos > 10 THEN
        -- Calcular la media de unidades por pedido del cliente usando LEFT JOIN
        SELECT COALESCE(SUM(lp.unidades), 0) / COUNT(p.id) INTO mediaUnidadesPorPedido
        FROM Pedidos p
        LEFT JOIN LineasPedido lp ON p.id = lp.pedidoId
        WHERE p.clienteId = clienteId;

        -- Establecer el límite de unidades (doble de la media si tiene 10 o más pedidos)
        IF mediaUnidadesPorPedido > 0 THEN
            SET limiteUnidades = FLOOR(mediaUnidadesPorPedido * 2);
        ELSE
            SET limiteUnidades = 200; -- Límite predeterminado si no hay líneas
        END IF;
    ELSE
        -- Si hay menos de 10 pedidos, el límite será el valor predeterminado
        SET limiteUnidades = 200;
    END IF;

    -- Sumar las unidades actuales del pedido
    SELECT SUM(unidades) INTO cantidadTotal
    FROM LineasPedido
    WHERE pedidoId = NEW.pedidoId;

    -- Incluir las unidades de la nueva línea
    SET cantidadTotal = COALESCE(cantidadTotal, 0) + NEW.unidades;

    -- Depuración: Usar una variable intermedia para el mensaje
    IF limiteUnidades = 0 THEN
        SET mensajeError = CONCAT('Error en cálculo: totalPedidos=', totalPedidos, 
                                  ', mediaUnidadesPorPedido=', CAST(mediaUnidadesPorPedido AS CHAR), 
                                  ', limiteUnidades=', CAST(limiteUnidades AS CHAR));
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = mensajeError;
    END IF;

    -- Verificar si la cantidad total supera el límite
    IF cantidadTotal > limiteUnidades THEN
        SET mensajeError = CONCAT('El pedido excede el límite de ', CAST(limiteUnidades AS CHAR), ' unidades permitidas para este cliente.');
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = mensajeError;
    END IF;
END //

DELIMITER ;


```
</details>
<details>
<summary><b>Datos de prueba</b></summary>

  ```sql
  INSERT INTO Usuarios (email, contraseña, nombre)
VALUES 
('cliente1@example.com', 'password123', 'Cliente Uno'), -- Cliente con más de 10 pedidos
('cliente2@example.com', 'password123', 'Cliente Dos'); -- Cliente con menos de 10 pedidos


INSERT INTO Clientes (usuarioId, direccionEnvio, codigoPostal, fechaNacimiento)
VALUES 
(1, 'Calle A, 123', '41001', '1990-05-10'), -- Cliente 1
(2, 'Calle B, 456', '41002', '1985-08-20'); -- Cliente 2


INSERT INTO TiposProducto (nombre)
VALUES 
('Electrónica');


INSERT INTO Productos (nombre, descripción, precio, tipoProductoId, puedeVenderseAMenores)
VALUES 
('Producto A', 'Descripción A', 100.00, 1, TRUE),
('Producto B', 'Descripción B', 200.00, 1, TRUE);


-- Pedido 1 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (1, 1, 50, 100.00);

-- Pedido 2 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (2, 1, 30, 100.00);

-- Pedido 3 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (3, 1, 40, 100.00);

-- Pedido 4 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (4, 1, 50, 100.00);

-- Pedido 5 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (5, 1, 60, 100.00);

-- Pedido 6 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (6, 1, 70, 100.00);

-- Pedido 7 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (7, 1, 80, 100.00);

-- Pedido 8 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (8, 1, 90, 100.00);

-- Pedido 9 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (9, 1, 100, 100.00);

-- Pedido 10 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (10, 1, 100, 100.00);

-- Pedido 11 sin línea inicial
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle A, 123', 1);


-- Pedido 12 del cliente 2 y su línea de pedido
INSERT INTO Pedidos (fechaRealizacion, direccionEntrega, clienteId)
VALUES (CURDATE(), 'Calle B, 456', 2);

INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (12, 1, 50, 100.00);

  ```
### Caso de prueba 1 - Caso Positivo: Cliente con más de 10 pedidos

Este caso de prueba tiene una media de unidades de ```65```, con lo que el límite es ```130```, y la línea no lo excede.
```sql
INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (11, 2, 50, 200.00); -- Línea válida con 50 unidades

```

### Caso de prueba 2 - Caso Negativo: Cliente con más de 10 pedidos

Este caso de prueba tiene una media de unidades de ```65```, con lo que el límite es ```130```, y la línea lo excede (50 anterior + 100 actual).
```sql
INSERT INTO LineasPedido (pedidoId, productoId, unidades, precio)
VALUES (11, 1, 100, 200.00); -- Línea válida con 100 unidades

```

</details>

## 3. Función - Índice de fidelidad de cliente

Implementa una función llamada `calcular_fidelidad_cliente` que calcule un **índice de fidelidad** para un cliente en función de su historial de compras y gasto total. Este índice se puede utilizar para clasificar a los clientes en niveles de fidelidad y definir estrategias como promociones, descuentos o beneficios. Inserte los datos que sean necesarios para probar que la función se comporta como se espera.

## Fórmula del Índice de Fidelidad
La fidelidad del cliente se calculará según los siguientes factores:
1. **Número de Pedidos**:
   - Cada pedido aumenta la fidelidad en un peso de `0.5`.
2. **Gasto Total**:
   - Cada euro gastado aumenta la fidelidad en un peso de `0.05`.

El cálculo del índice es:
```Índice de fidelidad = (Número de pedidos * 0.5)+(Gasto Total * 0.05)```


## Reglas
1. Si el cliente no tiene pedidos, el índice de fidelidad será `0`.
3. La función debe ser determinística y devolver el índice como un número decimal con dos decimales.

## Implementación de la Función
Crea una función en SQL con las siguientes características:
- **Nombre de la función**: `calcular_fidelidad_cliente`.
- **Parámetro de entrada**: `clienteId` (el identificador único del cliente).
- **Valor de retorno**: Un número decimal (`DECIMAL(10, 2)`) que representa el índice de fidelidad del cliente.

## Ejemplo de Uso

### Caso 1: Cliente con Pedidos
Un cliente con:
- **15 pedidos**.
- Un gasto total de **1200 euros**.

Al ejecutar la función:
```sql
SELECT calcular_fidelidad_cliente(1);
```
El resultado será ```Índice = (15 * 0.5) + (1200 * 0.05) = 7.5 + 60 = 67.5```

<details>
<summary><b>Solución</b></summary>

```sql
DELIMITER //

CREATE FUNCTION calcular_fidelidad_cliente(clienteId INT)
RETURNS DECIMAL(10, 2)
DETERMINISTIC
BEGIN
    DECLARE numeroPedidos INT;
    DECLARE gastoTotal DECIMAL(10, 2);
    DECLARE indiceFidelidad DECIMAL(10, 2);

    -- Obtener el número de pedidos del cliente
    SELECT COUNT(*) INTO numeroPedidos
    FROM Pedidos
    WHERE clienteId = clienteId;

    -- Obtener el gasto total del cliente
    SELECT COALESCE(SUM(lp.unidades * lp.precio), 0) INTO gastoTotal
    FROM LineasPedido lp
    JOIN Pedidos p ON lp.pedidoId = p.id
    WHERE p.clienteId = clienteId;

    -- Calcular el índice de fidelidad
    SET indiceFidelidad = (numeroPedidos * 0.5) + (gastoTotal * 0.05);

    RETURN indiceFidelidad;
END//

DELIMITER ;


```
</details>

## 4. Ejercicio: Vista - Pedidos, Facturación y Fidelidad del Último Mes

Crea una vista llamada `VistaPedidosFidelidad` que consolide información clave de los clientes sobre los pedidos realizados en el último mes, el total facturado y el índice de fidelidad. Esta vista permitirá analizar de forma rápida el comportamiento de los clientes más relevantes.

## Requisitos de la Vista
La vista debe mostrar los siguientes datos:
1. **Cliente**:
   - ID del cliente.
   - Nombre del cliente.
   - Email del cliente.
2. **Pedidos del Último Mes**:
   - Número total de pedidos realizados por el cliente en el último mes.
3. **Facturación del Último Mes**:
   - Total de euros facturados en el último mes por el cliente.
4. **Índice de Fidelidad**:
   - Calculado usando la función `calcular_fidelidad_cliente`.

## Detalles Técnicos
1. **Pedidos del Último Mes**:
   - Solo se incluirán los pedidos cuya fecha de realización (`fechaRealizacion`) sea del **mes anterior** al actual.
   - Se considerará el mes actual con la función `CURDATE()` y se calculará el mes anterior.
2. **Facturación**:
   - Se calculará sumando las cantidades (`unidades`) multiplicadas por el precio (`precio`) de las líneas de pedido correspondientes al cliente en el último mes.
3. **Fidelidad**:
   - El índice de fidelidad se obtendrá invocando la función `calcular_fidelidad_cliente` para cada cliente.

## Creación de la Vista
Define la vista `VistaPedidosFidelidad` con la siguiente estructura:
- **Campos**:
  - `clienteId`: Identificador único del cliente.
  - `nombreCliente`: Nombre completo del cliente.
  - `emailCliente`: Dirección de correo electrónico del cliente.
  - `pedidosUltimoMes`: Número de pedidos realizados por el cliente en el último mes.
  - `facturacionUltimoMes`: Total facturado por el cliente en el último mes.
  - `indiceFidelidad`: Índice de fidelidad calculado para el cliente.

## Ejemplo de Resultados

Supongamos que la base de datos contiene los siguientes datos:

- Cliente **Juan**:
  - 5 pedidos el mes pasado.
  - Total facturado: 1200 €.
  - Índice de fidelidad: 67.5.
- Cliente **Ana**:
  - 2 pedidos el mes pasado.
  - Total facturado: 300 €.
  - Índice de fidelidad: 15.0.

Al consultar la vista, se obtendrá:

| clienteId | nombreCliente | emailCliente        | pedidosUltimoMes | facturacionUltimoMes | indiceFidelidad |
|-----------|---------------|---------------------|------------------|----------------------|-----------------|
| 1         | Juan          | juan@example.com    | 5                | 1200.00             | 67.50           |
| 2         | Ana           | ana@example.com     | 2                | 300.00              | 15.00           |

## Ejemplo de Consulta
Una vez creada la vista, puedes consultarla con:
```sql
SELECT * FROM VistaPedidosFidelidad ORDER BY facturacionUltimoMes DESC;
```

<details>
<summary><b>Solución</b></summary>

```sql
CREATE OR REPLACE VIEW VistaPedidosFidelidad AS
SELECT 
    c.id AS clienteId,
    u.nombre AS nombreCliente,
    u.email AS emailCliente,
    COUNT(DISTINCT p.id) AS pedidosUltimoMes,
    COALESCE(SUM(lp.unidades * lp.precio), 0) AS facturacionUltimoMes,
    calcular_fidelidad_cliente(c.id) AS indiceFidelidad
FROM 
    Clientes c
JOIN 
    Usuarios u ON c.usuarioId = u.id
LEFT JOIN 
    Pedidos p ON c.id = p.clienteId AND MONTH(p.fechaRealizacion) = MONTH(CURDATE()) - 1 AND YEAR(p.fechaRealizacion) = YEAR(CURDATE())
LEFT JOIN 
    LineasPedido lp ON p.id = lp.pedidoId
GROUP BY 
    c.id, u.nombre, u.email;

```
</details>