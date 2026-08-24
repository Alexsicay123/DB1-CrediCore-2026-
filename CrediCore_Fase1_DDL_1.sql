/* ============================================================
   PROYECTO CREDICORE - FASE 1: CIMIENTOS DE TITANIO
   Script de creación de base de datos, esquemas, tablas y
   restricciones de dominio.
   Autor: Alex
   Fecha: Agosto 2026
   ============================================================ */

-- ------------------------------------------------------------
-- 1. CREACIÓN DE LA BASE DE DATOS
-- ------------------------------------------------------------
IF DB_ID('CrediCoreDB') IS NULL
BEGIN
    CREATE DATABASE CrediCoreDB;
END
GO

USE CrediCoreDB;
GO

-- ------------------------------------------------------------
-- 2. ESQUEMAS DE SEGURIDAD (separación lógica del negocio)
-- ------------------------------------------------------------
-- Operaciones: todo lo relacionado a clientes y créditos.
-- Garantias:   todo lo relacionado a los vehículos en garantía.
-- ------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Operaciones')
    EXEC('CREATE SCHEMA Operaciones');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'Garantias')
    EXEC('CREATE SCHEMA Garantias');
GO

-- ------------------------------------------------------------
-- 3. TABLA: Operaciones.Clientes
-- ------------------------------------------------------------
-- DPI usa CHAR(13) porque el DPI guatemalteco SIEMPRE tiene
-- 13 dígitos: longitud fija -> CHAR es más eficiente que VARCHAR.
-- Nombres/Apellidos/Correo usan VARCHAR porque su longitud
-- varía mucho de una persona a otra.
-- ------------------------------------------------------------
CREATE TABLE Operaciones.Clientes (
    IdCliente   INT IDENTITY(1,1) NOT NULL,
    Nombres     VARCHAR(100)      NOT NULL,
    Apellidos   VARCHAR(100)      NOT NULL,
    Telefono    VARCHAR(20)       NOT NULL,
    Correo      VARCHAR(100)      NOT NULL,
    DPI         CHAR(13)          NOT NULL,

    CONSTRAINT PK_Clientes PRIMARY KEY (IdCliente),
    CONSTRAINT UQ_Clientes_DPI UNIQUE (DPI)
);
GO

-- ------------------------------------------------------------
-- 4. TABLA: Garantias.Vehiculos
-- ------------------------------------------------------------
-- CHECK de antigüedad: se calcula contra el año actual del
-- servidor (YEAR(GETDATE())) para que la regla nunca quede
-- obsoleta, en vez de dejar "2011" fijo en el código.
--
-- Placa y NumeroChasis son UNIQUE cada uno por separado: un
-- vehículo real nunca comparte su placa ni su chasis con otro.
-- ------------------------------------------------------------
CREATE TABLE Garantias.Vehiculos (
    IdVehiculo              INT IDENTITY(1,1) NOT NULL,
    Modelo                  VARCHAR(50)       NOT NULL,
    Marca                   VARCHAR(50)       NOT NULL,
    Anio                    SMALLINT          NOT NULL,
    Color                   VARCHAR(30)       NOT NULL,
    NumeroTituloPropiedad   VARCHAR(30)       NOT NULL,
    Placa                   VARCHAR(15)       NULL,
    NumeroChasis            VARCHAR(30)       NULL,

    CONSTRAINT PK_Vehiculos PRIMARY KEY (IdVehiculo),
    CONSTRAINT UQ_Vehiculos_Placa UNIQUE (Placa),
    CONSTRAINT UQ_Vehiculos_Chasis UNIQUE (NumeroChasis),
    CONSTRAINT CK_Vehiculos_Antiguedad
        CHECK (Anio >= YEAR(GETDATE()) - 15)
);
GO

-- ------------------------------------------------------------
-- 5. TABLA: Operaciones.Creditos
-- ------------------------------------------------------------
-- MontoCapitalOtorgado y TasaInteresMensual usan DECIMAL(18,2)
-- / DECIMAL(5,2) en vez de FLOAT: el dinero exige precisión
-- exacta y FLOAT introduce errores de redondeo binario que son
-- inaceptables en un sistema financiero.
--
-- Estado tiene DEFAULT 'Activo' y FechaDesembolso tiene
-- DEFAULT GETDATE() para que cada préstamo quede sellado con
-- la hora real del servidor al momento de insertarse.
-- ------------------------------------------------------------
CREATE TABLE Operaciones.Creditos (
    IdCredito              INT IDENTITY(1,1)  NOT NULL,
    IdCliente               INT               NOT NULL,
    IdVehiculo               INT              NOT NULL,
    MontoCapitalOtorgado    DECIMAL(18,2)      NOT NULL,
    TasaInteresMensual      DECIMAL(5,2)       NOT NULL,
    Estado                  VARCHAR(20)        NOT NULL DEFAULT 'Activo',
    FechaDesembolso         DATETIME           NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_Creditos PRIMARY KEY (IdCredito),
    CONSTRAINT CK_Creditos_Monto CHECK (MontoCapitalOtorgado > 1000),
    CONSTRAINT CK_Creditos_Tasa CHECK (TasaInteresMensual >= 0)
);
GO

-- ============================================================
-- FIN DEL SCRIPT - Fase 1: Cimientos de Titanio
-- ============================================================
