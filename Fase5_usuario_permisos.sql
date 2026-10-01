/* ============================================================
   CrediCore - Fase 5: Cierre Frontend y BI
   Usuario de aplicación con permisos mínimos (sin usar sa)
   Lo usan: Excel (conexión ODBC) y app_credicore.py (Streamlit)
   ============================================================ */

USE master;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'UsuarioCrediCore')
    CREATE LOGIN UsuarioCrediCore WITH PASSWORD = 'CrediCore#2026', CHECK_POLICY = OFF;
GO

USE CrediCoreDB;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'UsuarioCrediCore')
    CREATE USER UsuarioCrediCore FOR LOGIN UsuarioCrediCore;
GO

-- Solo puede leer la vista segura y ejecutar el procedimiento de pagos.
-- No tiene acceso directo a las tablas base.
GRANT SELECT  ON vw_AtencionAlCliente TO UsuarioCrediCore;
GRANT EXECUTE ON SP_ProcesarPago      TO UsuarioCrediCore;
GO

-- Verificación
SELECT name FROM sys.database_principals WHERE name = 'UsuarioCrediCore';
GO
