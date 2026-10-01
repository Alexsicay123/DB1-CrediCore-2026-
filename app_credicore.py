import streamlit as st
import pandas as pd
import pyodbc

# 1. Configuración de conexión (SQL Server en Docker, con port forwarding a localhost)
SERVER = 'localhost,1433'
DATABASE = 'CrediCoreDB'
USERNAME = 'UsuarioCrediCore'
PASSWORD = 'CrediCore#2026'


def get_driver():
    """Usa el driver ODBC de SQL Server más reciente que esté instalado."""
    drivers = [d for d in pyodbc.drivers() if 'SQL Server' in d]
    return sorted(drivers)[-1] if drivers else 'ODBC Driver 17 for SQL Server'


def get_connection():
    conn_str = (
        f'DRIVER={{{get_driver()}}};SERVER={SERVER};DATABASE={DATABASE};'
        f'UID={USERNAME};PWD={PASSWORD};TrustServerCertificate=yes;'
    )
    return pyodbc.connect(conn_str)


st.set_page_config(page_title="ERP CrediCore", layout="centered")
st.title("🏦 CrediCore - Módulo de Caja")
st.markdown("Interfaz conectada directamente al motor transaccional de SQL Server")

# Mensajes que sobreviven al st.rerun()
if "mensaje_ok" in st.session_state:
    st.success(st.session_state.pop("mensaje_ok"))

# 2. Leer la vista segura
st.subheader("Estado de Cuenta (Vista Segura)")
try:
    conn = get_connection()
    # Llamamos a la vista, no a las tablas
    df = pd.read_sql("SELECT * FROM vw_AtencionAlCliente", conn)
    conn.close()
    st.dataframe(df, use_container_width=True)
except Exception as e:
    st.error(f"Error de conexión a la BD: {e}")

st.divider()

# 3. Formulario para ejecutar el Procedimiento Almacenado
st.subheader("Procesar Pago de Cuota")
with st.form("form_pago", clear_on_submit=True):
    id_credito = st.number_input("Número de Crédito (ID)", min_value=1, step=1)
    monto_pago = st.number_input("Monto a Abonar (Q)", min_value=1.0, step=100.0)
    btn_pagar = st.form_submit_button("Ejecutar Transacción")

if btn_pagar:
    try:
        conn = get_connection()
        cursor = conn.cursor()
        # Llamada parametrizada al SP (evita SQL Injection)
        cursor.execute(
            "EXEC SP_ProcesarPago @IdCredito = ?, @MontoAbono = ?",
            int(id_credito), float(monto_pago)
        )
        conn.commit()
        conn.close()
        st.session_state["mensaje_ok"] = "¡Pago procesado con éxito en SQL Server!"
        st.rerun()  # Recarga la pantalla para actualizar la tabla
    except Exception as e:
        # Aquí capturamos el RAISERROR que programamos en el TRY...CATCH de SQL
        st.error(f"Transacción Rechazada por el Motor: {e}")
