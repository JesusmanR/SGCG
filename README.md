# Control de gastos

Aplicación local de escritorio para registrar y revisar gastos. La documentación de producto está en `docs/` y el proyecto Flutter para Windows está en `app/`.

## Estado actual

La versión en desarrollo incluye perfiles locales con clave, ingresos y gastos, categorías personalizables, adjuntos locales, resumen de saldo, papelera recuperable y reportes exportables a PDF, CSV y Excel. El reconocimiento OCR se ejecuta localmente con Tesseract y un modelo de español; los PDF se convierten a imágenes en el dispositivo. La rama `codex/copias-seguridad` añade respaldos locales y restauración, y `codex/instalador-windows` prepara el instalador.

Los datos se guardan localmente en SQLite. El OCR no requiere conexión ni envía documentos a internet. El archivo de respaldo incluye datos, verificadores de clave y adjuntos, y no está cifrado; se debe guardar de forma privada.

## Ejecutar en Windows

Con Flutter instalado, desde la carpeta `app`:

```powershell
flutter run -d windows
```

La compilación actual está en:

```text
app/build/windows/x64/runner/Release/control_gastos.exe
```

Los ejecutables y el instalador se generan localmente y no se guardan en Git. Para usar el programa sin instalarlo, extrae el contenido completo de la carpeta `Release` y abre `control_gastos.exe`.

Para preparar el entorno de desarrollo, instala Tesseract 5 para Windows y ejecuta `scripts/prepare-local-ocr.ps1`. El script copia el motor y sus DLL a `.tools/tesseract`, descarga el modelo español y conserva la licencia. El instalador incluye estos componentes automáticamente. Si no se encuentra el motor, el registro manual sigue disponible.

Para compilar nuevamente la versión Windows:

```powershell
flutter build windows --release
```

El ejecutable se distribuye junto con los archivos de la carpeta `Release`.

## Crear instalador de Windows

Con Inno Setup 7 instalado, desde la carpeta raíz del proyecto ejecuta:

```powershell
.\scripts\build-windows-installer.ps1
```

El instalador se genera en `dist/installer/Control-de-gastos-Setup-1.0.0.exe`. Se instala en el perfil de Windows, crea un acceso directo opcional en el escritorio y conserva los datos personales al desinstalar.

## Documentos del proyecto

- `docs/especificacion-funcional-v0.2.md`: alcance y criterios funcionales.
- `docs/arquitectura-tecnica-v0.1.md`: arquitectura propuesta y decisiones técnicas.
- `docs/diseno-de-pantallas-v0.1.md`: navegación y pantallas iniciales.

## Decisiones provisionales

Cada perfil tiene sus propios gastos. La aplicación permite varias personas en el mismo equipo, pero aún no tiene libros compartidos ni sincronización. La clave local protege el acceso dentro de la aplicación; la base de datos y los archivos todavía no están cifrados en reposo.
