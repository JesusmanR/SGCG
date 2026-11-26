# Especificación funcional — Control de gastos

**Versión:** 0.2  
**Estado:** alcance base aprobado; implementación inicial en desarrollo  
**Fecha:** 5 de noviembre de 2026

## 1. Propósito

Aplicación personal para registrar y analizar gastos. La primera versión se instalará y ejecutará en Windows, trabajará sin conexión para las funciones principales y guardará los datos en el equipo. El reconocimiento de documentos requerirá conexión a internet.

El diseño debe permitir incorporar posteriormente aplicaciones para Android e iOS y una versión web con sincronización, sin que esta expansión forme parte de la primera entrega.

## 2. Objetivos de la primera versión

- Registrar gastos con datos manuales o con ayuda del reconocimiento de un recibo.
- Organizar los gastos en categorías personalizables.
- Consultar totales y gráficos por fechas y categorías.
- Generar informes diarios, semanales, mensuales y anuales.
- Exportar informes a PDF, CSV y Excel.
- Mantener los datos en el equipo y permitir crear y restaurar copias de seguridad.

## 3. Alcance

### Incluido

- Aplicación de escritorio para Windows, distribuible mediante instalador `.exe`.
- Uso local en un solo equipo, con perfiles de usuario e inicio de sesión local; sin cuentas en la nube ni sincronización en la primera versión.
- Moneda de trabajo: peso colombiano (COP).
- Creación, edición, consulta y eliminación de gastos.
- Creación, edición, consulta y eliminación de ingresos.
- Categorías y métodos de pago personalizables.
- Adjuntos asociados a gastos: JPG/JPEG, PNG y PDF; otros documentos podrán añadirse sin OCR en la primera versión.
- Lectura asistida de recibos mediante un servicio en línea, con revisión antes de guardar.
- Panel de resumen, gráficos, filtros e informes.
- Exportación a PDF, CSV y XLSX.
- Copias de seguridad y restauración.
- Perfiles locales para identificar quién está usando la aplicación.

### Fuera del alcance inicial

- Aplicaciones Android/iOS y sitio web.
- Sincronización entre dispositivos o almacenamiento en la nube de la aplicación.
- Presupuestos, cuentas bancarias y conversión de monedas.
- Integración con bancos, tarjetas o sistemas contables.
- Automatización de pagos o movimientos de dinero.

## 4. Tipos de usuario

La primera versión permitirá crear varios perfiles locales en el mismo equipo. Cada perfil iniciará sesión con su nombre y una clave local. Los gastos y categorías serán privados por perfil; no habrá acceso compartido entre perfiles en la primera versión. El nombre del perfil que crea o modifica un gasto se conservará como dato de auditoría.

El inicio de sesión local no es una cuenta en la nube y no permite recuperar la clave mediante internet. Las claves no se almacenarán en texto plano. El procedimiento local para restablecer una clave se definirá en el diseño técnico.

## 5. Datos de un gasto

Cada gasto tendrá estos campos:

| Campo | Requisito | Regla propuesta |
|---|---|---|
| Nombre | Obligatorio | Texto personalizado; por ejemplo, “Compra semanal” o “Internet casa”. |
| Valor | Obligatorio | Mayor que cero; se presenta en COP. |
| Fecha | Obligatorio | Fecha de compra o pago; por defecto, la fecha actual. |
| Categoría | Obligatoria | Una categoría activa; puede cambiarse después. |
| Método de pago | Opcional | Selección personalizable, como efectivo, débito o crédito. |
| Comercio o beneficiario | Opcional | Texto libre. |
| Nota | Opcional | Texto libre. |
| Adjuntos | Opcional | Uno o más archivos relacionados con el gasto. |
| Origen | Interno | Indica si se ingresó manualmente o se propuso desde un documento. |
| Fecha de creación y actualización | Interno | Para trazabilidad y futuras migraciones. |
| Usuario creador y modificador | Interno | Identifica el perfil local que creó o modificó el registro. |

Para COP se recomienda mostrar valores sin decimales de forma predeterminada. Si se requieren centavos, se podrán admitir hasta dos decimales. La base de datos debe guardar importes con precisión decimal, evitando errores de redondeo binario.

## 5.1 Ingresos y saldo

Cada ingreso tendrá nombre, valor en COP, fecha, origen opcional y nota opcional. El perfil podrá crear, editar, consultar, buscar y enviar ingresos a la papelera, igual que los gastos.

El saldo se calculará como la suma de ingresos activos menos la suma de gastos activos, desde el inicio del registro. Cada gasto disminuye el saldo calculado y cada ingreso lo aumenta. Los elementos en la papelera no cuentan. Se permitirá registrar gastos que dejen saldo negativo; la aplicación lo mostrará claramente y no bloqueará el registro.

Para reflejar dinero que ya existía antes de empezar a usar la aplicación, se recomienda registrar un ingreso llamado “Saldo inicial”.

## 6. Categorías y métodos de pago

- La aplicación ofrecerá categorías iniciales: Servicios, Compras, Restaurantes, Transporte, Salud, Vivienda, Entretenimiento, Educación, Otros.
- El usuario podrá crear, renombrar, ordenar y archivar categorías.
- Una categoría con gastos asociados no se eliminará físicamente; se archivará para conservar los informes históricos.
- Se ofrecerán métodos de pago iniciales: Efectivo, Débito, Crédito, Transferencia y Otro.
- Categorías y métodos archivados no aparecerán al crear un nuevo gasto, pero seguirán visibles en registros anteriores.
- Las categorías personalizadas pertenecerán al perfil local que las creó.

### Inicio de sesión local

- En el primer inicio se podrá crear el perfil administrador local.
- Se podrán crear perfiles locales adicionales desde la administración.
- La pantalla de inicio permitirá elegir un perfil e ingresar su clave.
- Recomendación inicial: bloquear la sesión después de 10 minutos de inactividad.
- En la primera versión cada perfil administra sus propios datos; no habrá roles ni acceso compartido.

## 7. Flujos principales

### 7.1 Registrar un gasto manualmente

1. El usuario elige “Nuevo gasto”.
2. Introduce nombre, valor, fecha y categoría; puede añadir método de pago, comercio, nota y adjunto.
3. La aplicación valida los campos requeridos y el formato del valor.
4. El usuario guarda el gasto.
5. El gasto aparece en la lista, los totales y los informes aplicables.

### 7.2 Registrar un gasto desde un documento

1. El usuario selecciona una imagen JPG/JPEG, PNG o PDF, o toma una foto cuando el equipo disponga de cámara.
2. La aplicación indica que el reconocimiento se ejecuta localmente en el equipo.
3. Tesseract propone texto y la aplicación intenta identificar comercio, fecha y total.
4. La aplicación presenta los valores detectados y permite corregirlos. Ningún dato se guarda como gasto hasta que el usuario confirme.
5. El usuario asigna o confirma nombre, categoría y método de pago, y guarda.
6. Si falla el reconocimiento, el usuario puede completar el formulario manualmente.

Los valores detectados se consideran sugerencias, no una validación contable. El OCR inicial se limitará a documentos de hasta 10 páginas y 15 MB. El documento original solo se conserva como adjunto del gasto después de confirmar el registro. DOCX y otros documentos se podrán adjuntar, pero no se procesarán con OCR en la primera versión.

### 7.3 Consultar gastos

- Vista de lista con fecha, nombre, categoría, método de pago y valor.
- Búsqueda por nombre, comercio y nota.
- Filtros por intervalo de fechas, categoría y método de pago.
- Orden por fecha o valor, ascendente o descendente.
- Acceso al detalle para editar, mover a papelera, restaurar desde papelera y abrir adjuntos.
- La papelera permitirá restaurar un gasto; el borrado definitivo requerirá confirmación.

### 7.4 Revisar resumen y gráficos

- Total gastado en el intervalo seleccionado.
- Comparación de gasto por categoría.
- Ingresos del mes, gastos del mes y saldo disponible acumulado.
- Evolución del gasto en el tiempo.
- Acceso desde un segmento o categoría al listado filtrado correspondiente.
- Mensajes claros para periodos sin gastos.

## 8. Periodos e informes

- **Diario:** un día calendario.
- **Semanal:** lunes a domingo.
- **Mensual:** del primer al último día del mes calendario.
- **Anual:** del 1 de enero al 31 de diciembre.
- Zona horaria de presentación: America/Bogota.
- Se permitirán intervalos personalizados además de los periodos rápidos.
- Los totales incluirán los gastos cuya fecha esté dentro del intervalo, inclusive.
- Los filtros por categoría y método de pago se aplicarán tanto al resumen como al detalle exportado.
- El informe mostrará ingresos, gastos y saldo neto del periodo; los filtros de categoría y método de pago filtran gastos, mientras que los ingresos se presentan por separado.

Cada informe incluirá periodo, fecha de generación, total general, totales por categoría y detalle de gastos. Las exportaciones PDF, CSV y Excel deben reflejar los mismos filtros y totales.

## 9. Copias de seguridad y protección de datos

- La base de datos y los adjuntos residirán localmente en el perfil del usuario de Windows.
- Cada perfil local tendrá sus propios datos y adjuntos; la sesión activa determinará el conjunto mostrado.
- El usuario podrá crear una copia de seguridad en una ubicación elegida y restaurarla desde la aplicación.
- La copia debe incluir base de datos, categorías, métodos de pago y adjuntos.
- Antes de restaurar, se mostrará qué datos locales serán reemplazados y se recomendará crear una copia actual.
- Los gastos y adjuntos no se envían a servidores en la versión local. El OCR se ejecuta en el dispositivo y no tiene costo por uso.
- Si en el futuro se incorpora OCR remoto, deberá aprobarse y documentar el tratamiento de datos antes de activarlo.

## 10. Requisitos de calidad

- Las funciones de registro, consulta, gráficos e informes deben funcionar sin conexión.
- Un fallo del OCR no debe impedir registrar un gasto manualmente.
- Los errores al abrir un adjunto deben mostrarse sin bloquear la aplicación.
- El instalador debe permitir instalar, actualizar y desinstalar la aplicación sin borrar silenciosamente los datos del usuario.
- Los formatos de fecha e importe deben ser legibles para una persona usuaria en Colombia.
- La aplicación debe permitir migrar la estructura local de datos entre versiones.
- Las operaciones de guardar, editar y restaurar deben informar claramente si terminan o fallan.

## 11. Criterios de aceptación iniciales

1. Es posible registrar un gasto válido y verlo en la lista y en el total del periodo.
2. No se puede guardar un gasto sin nombre, valor válido, fecha y categoría.
3. Al editar un gasto se actualizan sus totales y gráficos sin duplicarlo.
4. Archivar una categoría conserva y clasifica correctamente los gastos históricos.
5. Los informes diario, semanal, mensual y anual respetan los límites de calendario definidos.
6. PDF, CSV y XLSX contienen el mismo conjunto filtrado de gastos y totales coherentes.
7. El OCR siempre permite revisar y corregir los campos antes de guardar.
8. El registro, la consulta y el OCR local funcionan sin conexión.
9. Una copia creada y restaurada recupera los gastos y adjuntos incluidos.
10. Cada gasto registra el perfil que lo creó y el último perfil que lo modificó.
11. Un perfil no puede consultar los gastos de otro perfil en la primera versión.
12. Un gasto enviado a la papelera puede restaurarse y deja de incluirse en totales mientras permanezca allí.
13. Registrar un ingreso aumenta el saldo por el mismo valor; registrar un gasto lo reduce.
14. Editar, restaurar o mover a papelera un ingreso recalcula el saldo.
15. Un saldo negativo se muestra y no impide registrar el gasto.

## 12. Decisiones tomadas y recomendaciones

1. **Identificación:** habrá inicio de sesión con perfiles locales para saber quién está usando la aplicación. El nombre e identidad visual del producto siguen pendientes; se usará un nombre provisional durante el desarrollo.
2. **Eliminación:** los gastos irán a una papelera recuperable; la eliminación definitiva requerirá una acción separada.
3. **Adjuntos:** JPG/JPEG, PNG y PDF, hasta 15 MB por archivo. Para OCR, máximo 10 páginas por documento. Otros tipos comunes podrán guardarse como adjuntos, pero no tendrán OCR inicialmente.
4. **OCR:** Tesseract 5 con el modelo `spa` de `tessdata_fast` se empaqueta para lectura local sin conexión ni cargos por uso. El parser propio solo propone comercio, fecha y total; se debe medir la precisión con recibos colombianos reales y permitir siempre la revisión manual. [Instalación de Tesseract](https://github.com/tesseract-ocr/tessdoc/blob/main/Installation.md), [modelos de idioma](https://github.com/tesseract-ocr/tessdoc/blob/main/Data-Files.md).
5. **Respaldo:** copia manual en la primera versión; los recordatorios podrán añadirse después.
6. **Instalador:** instalación por usuario para evitar permisos de administrador.

El OCR local no necesita claves ni transmite documentos. El instalador debe incluir el motor, el modelo español y los avisos de licencia correspondientes.

## 13. Evolución futura

Cuando se apruebe la fase móvil/web, se añadirá una API y sincronización. Desde el inicio, cada entidad tendrá un identificador estable y una versión de esquema para facilitar migraciones. La estrategia de conflictos y la vinculación de perfiles locales con cuentas en línea se definirán antes de habilitar la sincronización.
