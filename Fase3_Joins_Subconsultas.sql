/* ============================================================
   TAREA 5 - PROYECTO CREDICORE (FASE 3)
   El Tejido Relacional y Analisis Estrategico
   Curso: Base de Datos
   ============================================================ */

USE CrediCoreDB;
GO

/* ============================================================
   PARTE A: EL ESCUDO RELACIONAL (DDL Y DML DE PRUEBA)
   ============================================================ */

-- 1. Activacion de Restricciones Foraneas (FOREIGN KEY)
-- Conecta formalmente Operaciones.Creditos con Operaciones.Clientes
ALTER TABLE Operaciones.Creditos
ADD CONSTRAINT FK_Creditos_Clientes
    FOREIGN KEY (IdCliente) REFERENCES Operaciones.Clientes(IdCliente);
GO

-- Conecta formalmente Operaciones.Creditos con Garantias.Vehiculos
ALTER TABLE Operaciones.Creditos
ADD CONSTRAINT FK_Creditos_Vehiculos
    FOREIGN KEY (IdVehiculo) REFERENCES Garantias.Vehiculos(IdVehiculo);
GO

-- 2. Prueba de la Destruccion (Obligatoria)
-- Se intenta borrar a un cliente que actualmente tiene un credito asignado.
-- El motor DEBE bloquear la eliminacion para evitar registros huerfanos.
DELETE FROM Operaciones.Clientes WHERE IdCliente = 1378;
-- Resultado esperado: SQL Error [547] [23000] - conflicto con FK_Creditos_Clientes
GO

/* ============================================================
   PARTE B: RECONSTRUCCION DE LA REALIDAD (JOINS)
   ============================================================ */

-- 1. Reporte Maestro (INNER JOIN Triple)
-- Relaciona las 3 tablas para mostrar la fotografia completa de la operacion.
SELECT
    c.Nombres + ' ' + c.Apellidos AS NombreCliente,
    c.Telefono,
    v.Marca                       AS MarcaVehiculo,
    v.Placa,
    cr.MontoCapitalOtorgado       AS MontoDelCredito,
    cr.Estado                     AS EstadoActual
FROM Operaciones.Creditos cr
INNER JOIN Operaciones.Clientes c ON cr.IdCliente = c.IdCliente
INNER JOIN Garantias.Vehiculos v ON cr.IdVehiculo = v.IdVehiculo;
GO

-- 2. Mineria de Clientes Inactivos (LEFT JOIN)
-- Devuelve exclusivamente el nombre y telefono de los clientes que NUNCA
-- han tramitado un credito (el cruce debe buscar los NULL en la tabla hija).
SELECT
    c.Nombres + ' ' + c.Apellidos AS NombreCliente,
    c.Telefono
FROM Operaciones.Clientes c
LEFT JOIN Operaciones.Creditos cr ON c.IdCliente = cr.IdCliente
WHERE cr.IdCliente IS NULL;
GO

/* ============================================================
   PARTE C: EL CEREBRO ANALITICO (SUBCONSULTAS)
   ============================================================ */

-- 1. El Filtro Dinamico (Subconsulta en el WHERE)
-- Encuentra los clientes cuyo credito otorgado sea ESTRICTAMENTE MAYOR
-- al promedio historico de todos los prestamos registrados.
-- El promedio se calcula dinamicamente dentro de la subconsulta
-- (nunca se escribe el valor numerico a mano).
SELECT
    c.Nombres + ' ' + c.Apellidos AS NombreCliente,
    cr.MontoCapitalOtorgado       AS MontoDelCredito
FROM Operaciones.Creditos cr
INNER JOIN Operaciones.Clientes c ON cr.IdCliente = c.IdCliente
WHERE cr.MontoCapitalOtorgado > (
    SELECT AVG(MontoCapitalOtorgado) FROM Operaciones.Creditos
);
GO

-- 2. Patrones Anidados (Subconsulta con IN)
-- Encuentra el nombre de los clientes y su numero de credito, pero solo
-- para aquellos que hayan dejado como garantia vehiculos del ano 2011
-- hacia atras (evaluacion del ano hecha internamente en la subconsulta).
SELECT
    c.Nombres + ' ' + c.Apellidos AS NombreCliente,
    cr.MontoCapitalOtorgado       AS MontoDelCredito
FROM Operaciones.Creditos cr
INNER JOIN Operaciones.Clientes c ON cr.IdCliente = c.IdCliente
WHERE cr.IdVehiculo IN (
    SELECT IdVehiculo FROM Garantias.Vehiculos WHERE Anio <= 2011
);
GO
