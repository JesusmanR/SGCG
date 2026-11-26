# Control de gastos

Aplicación local de escritorio para registrar y revisar gastos. La documentación de producto está en `docs/` y el proyecto Flutter para Windows está en `app/`.

## Estado actual

La versión en desarrollo incluye perfiles locales con clave, ingresos y gastos, categorías personalizables, adjuntos locales, resumen de saldo, papelera recuperable y reportes exportables a PDF, CSV y Excel. La rama `codex/ocr-integracion` añade la interfaz de lectura de comprobantes y una pasarela OCR preparada para Google Document AI. La rama `codex/copias-seguridad` añade respaldos locales y restauración.

Los datos se guardan localmente en SQLite. OCR aún requiere crear y configurar el servicio de Google Cloud antes de poder usarse. El archivo de respaldo incluye datos, verificadores de clave y adjuntos, y no está cifrado; se debe guardar de forma privada. El instalador de Windows sigue pendiente.

## Ejecutar en Windows

Con Flutter instalado, desde la carpeta `app`:

```powershell
flutter run -d windows
```

La compilación actual está en:

```text
app/build/windows/x64/runner/Release/control_gastos.exe
```

Los ejecutables y ZIP portables se generan localmente y no se guardan en Git. Para distribuir una compilación, extrae el contenido completo de la carpeta `Release` y abre `control_gastos.exe`; todavía no hay instalador.

La integración OCR se configura al compilar con `OCR_GATEWAY_URL` (dirección HTTPS terminada en `/v1/receipt:analyze`) y `OCR_GATEWAY_TOKEN`. La pasarela y sus pasos de configuración están en `backend/ocr-gateway/README.md`. El token embebido en una compilación de escritorio es extraíble; no se debe distribuir una compilación configurada con un token compartido.

Para compilar nuevamente la versión Windows:

```powershell
flutter build windows --release
```

El ejecutable se distribuye junto con los archivos de la carpeta `Release`; todavía no hay instalador.

## Documentos del proyecto

- `docs/especificacion-funcional-v0.2.md`: alcance y criterios funcionales.
- `docs/arquitectura-tecnica-v0.1.md`: arquitectura propuesta y decisiones técnicas.
- `docs/diseno-de-pantallas-v0.1.md`: navegación y pantallas iniciales.

## Decisiones provisionales

Cada perfil tiene sus propios gastos. La aplicación permite varias personas en el mismo equipo, pero aún no tiene libros compartidos ni sincronización. La clave local protege el acceso dentro de la aplicación; la base de datos y los archivos todavía no están cifrados en reposo.
