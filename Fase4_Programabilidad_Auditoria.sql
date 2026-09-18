/* ============================================================
   CrediCore - Fase 4: Programabilidad y Auditoría Activa
   Autor: Alex
   Contiene: Vista de abstracción, SP transaccional, tabla de
   auditoría y trigger AFTER UPDATE.
   AJUSTA los nombres de columnas marcados con -- si difieren
   de tu esquema real (Clientes, Creditos, Vehiculos).
   ============================================================ */

USE CrediCoreDB;
GO

/* ------------------------------------------------------------
   PASO PREVIO: tu tabla Creditos no tiene columna SaldoActual
   todavía. La agregamos e inicializamos con el monto otorgado.
   (Separado en 2 batches con GO porque SQL Server no reconoce
   una columna nueva en el mismo batch donde se crea).
------------------------------------------------------------ */
IF NOT EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'Operaciones' AND TABLE_NAME = 'Creditos' AND COLUMN_NAME = 'SaldoActual'
)
BEGIN
    ALTER TABLE Operaciones.Creditos ADD SaldoActual DECIMAL(18,2) NULL;
END
GO

UPDATE Operaciones.Creditos
SET SaldoActual = MontoCapitalOtorgado
WHERE SaldoActual IS NULL;
GO

/* ------------------------------------------------------------
   PARTE A: VISTA DE ABSTRACCIÓN
   vw_AtencionAlCliente
   Cruza Clientes + Creditos + Vehiculos, enmascarando datos
   sensibles (NO expone DPI, teléfono ni chasis).
------------------------------------------------------------ */
IF OBJECT_ID('dbo.vw_AtencionAlCliente', 'V') IS NOT NULL
    DROP VIEW dbo.vw_AtencionAlCliente;
GO

CREATE VIEW dbo.vw_AtencionAlCliente AS
SELECT
    cli.Nombres + ' ' + cli.Apellidos          AS NombreDelCliente,
    cre.IdCredito                              AS NumeroDeCredito,
    veh.Marca                                  AS MarcaDelVehiculo,
    cre.Estado                                 AS EstadoDelCredito,
    cre.SaldoActual                            AS SaldoActual
FROM Operaciones.Creditos AS cre
INNER JOIN Operaciones.Clientes AS cli
    ON cre.IdCliente = cli.IdCliente
INNER JOIN Garantias.Vehiculos AS veh
    ON cre.IdVehiculo = veh.IdVehiculo;
GO

-- Prueba: debe verse SOLO Nombre, NumeroDeCredito, Marca, Estado y Saldo.
-- SELECT * FROM dbo.vw_AtencionAlCliente;


/* ------------------------------------------------------------
   Tabla de soporte requerida por el SP (si no existe todavía)
   Operaciones.HistorialPagos
------------------------------------------------------------ */
IF OBJECT_ID('Operaciones.HistorialPagos', 'U') IS NULL
BEGIN
    CREATE TABLE Operaciones.HistorialPagos (
        IdPago      INT IDENTITY(1,1) PRIMARY KEY,
        IdCredito   INT NOT NULL,
        MontoAbono  DECIMAL(18,2) NOT NULL,
        FechaPago   DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_HistorialPagos_Creditos
            FOREIGN KEY (IdCredito) REFERENCES Operaciones.Creditos(IdCredito)
    );
END
GO


/* ------------------------------------------------------------
   PARTE B: PROCEDIMIENTO ALMACENADO
   SP_ProcesarPago
   Lógica transaccional con control de errores.
------------------------------------------------------------ */
IF OBJECT_ID('dbo.SP_ProcesarPago', 'P') IS NOT NULL
    DROP PROCEDURE dbo.SP_ProcesarPago;
GO

CREATE PROCEDURE dbo.SP_ProcesarPago
    @IdCredito   INT,
    @MontoAbono  DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SaldoActual DECIMAL(18,2);

    BEGIN TRAN;
    BEGIN TRY

        -- Bloqueamos la fila para leer el saldo vigente de forma segura
        SELECT @SaldoActual = SaldoActual
        FROM Operaciones.Creditos WITH (UPDLOCK, ROWLOCK)
        WHERE IdCredito = @IdCredito;

        IF @SaldoActual IS NULL
        BEGIN
            RAISERROR('El crédito especificado no existe.', 16, 1);
        END

        -- Validación de negocio: el abono no puede exceder el saldo
        IF @MontoAbono > @SaldoActual
        BEGIN
            RAISERROR('El monto del abono excede el saldo actual del crédito.', 16, 1);
        END

        -- Registrar el pago
        INSERT INTO Operaciones.HistorialPagos (IdCredito, MontoAbono, FechaPago)
        VALUES (@IdCredito, @MontoAbono, GETDATE());

        -- Actualizar el saldo del crédito (esto dispara el Trigger de auditoría)
        UPDATE Operaciones.Creditos
        SET SaldoActual = SaldoActual - @MontoAbono
        WHERE IdCredito = @IdCredito;

        COMMIT TRAN;

        PRINT 'Pago procesado correctamente.';

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRAN;

        DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 51000, @MensajeError, 1;
    END CATCH
END
GO

-- Prueba de éxito:
-- EXEC dbo.SP_ProcesarPago @IdCredito = 1, @MontoAbono = 500.00;

-- Prueba de fallo controlado (debe hacer ROLLBACK):
-- EXEC dbo.SP_ProcesarPago @IdCredito = 1, @MontoAbono = 999999999;


/* ------------------------------------------------------------
   PARTE C: EL AUDITOR SILENCIOSO
   Esquema + tabla de bitácora + trigger AFTER UPDATE
------------------------------------------------------------ */
IF SCHEMA_ID('Auditoria') IS NULL
    EXEC('CREATE SCHEMA Auditoria');
GO

IF OBJECT_ID('Auditoria.Logs_Creditos', 'U') IS NULL
BEGIN
    CREATE TABLE Auditoria.Logs_Creditos (
        IdLog        INT IDENTITY(1,1) PRIMARY KEY,
        Accion       NVARCHAR(50)     NOT NULL,
        ValorAnterior DECIMAL(18,2)   NULL,
        ValorNuevo    DECIMAL(18,2)   NULL,
        FechaHora     DATETIME        NOT NULL DEFAULT GETDATE()
    );
END
GO

IF OBJECT_ID('Operaciones.TR_AuditoriaCreditos', 'TR') IS NOT NULL
    DROP TRIGGER Operaciones.TR_AuditoriaCreditos;
GO

CREATE TRIGGER Operaciones.TR_AuditoriaCreditos
ON Operaciones.Creditos
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Solo audita si realmente cambió la tasa de interés
    IF UPDATE(TasaInteresMensual)
    BEGIN
        INSERT INTO Auditoria.Logs_Creditos (Accion, ValorAnterior, ValorNuevo, FechaHora)
        SELECT
            'UPDATE_TASA_INTERES',
            d.TasaInteresMensual,
            i.TasaInteresMensual,
            GETDATE()
        FROM inserted i
        INNER JOIN deleted d
            ON i.IdCredito = d.IdCredito
        WHERE i.TasaInteresMensual <> d.TasaInteresMensual;
    END
END
GO

-- Prueba manual (simula al DBA intentando bajar la tasa "a escondidas"):
-- UPDATE Operaciones.Creditos SET TasaInteresMensual = 5.0 WHERE IdCredito = 1;
-- SELECT * FROM Auditoria.Logs_Creditos;
