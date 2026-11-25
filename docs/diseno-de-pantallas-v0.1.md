# Diseño de pantallas — Control de gastos

**Versión:** 0.1  
**Estado:** propuesta de experiencia para validar  
**Plataforma inicial:** Windows  
**Relacionado con:** [Especificación funcional](especificacion-funcional-v0.2.md) y [arquitectura técnica](arquitectura-tecnica-v0.1.md)

## 1. Principios de interfaz

- Mostrar valores en COP con separadores locales y sin decimales cuando sean cero.
- Mantener visible la fecha y el perfil activo.
- Permitir registrar un gasto desde las pantallas principales en pocos pasos.
- No depender del color como único medio para distinguir categorías o estados.
- Usar confirmación antes de borrar definitivamente, restaurar una copia o enviar un documento a OCR.
- Ofrecer estados claros cuando no hay datos, hay un error o no hay conexión.
- Priorizar una interfaz de escritorio con navegación lateral; en móvil se transformará en navegación compacta.

## 2. Navegación principal

```text
┌──────────────────────────────────────────────────────────────────────┐
│ Control de gastos                            Perfil activo ▾   ⚙     │
├─────────────┬────────────────────────────────────────────────────────┤
│ Resumen     │                                                        │
│ Gastos      │                 Área de la pantalla                    │
│ Ingresos    │                                                        │
│ Informes    │                                                        │
│ Categorías  │                                                        │
│ Papelera    │                                                        │
│             │                                                        │
│ + Gasto     │                                                        │
│             │                                                        │
│             │                                                        │
└─────────────┴────────────────────────────────────────────────────────┘
```

La barra inferior o menú del perfil incluirá cerrar sesión. Ajustes contendrá perfiles, seguridad, copias de seguridad y preferencias.

## 3. Pantallas

### 3.1 Inicio y selección de perfil

**Objetivo:** identificar a la persona que usa la aplicación.

```text
┌─────────────────────────────────────────┐
│             Control de gastos           │
│                                         │
│  ¿Quién va a usar la aplicación?        │
│  [ Seleccionar perfil              ▾ ] │
│  Clave  [••••••••                     ] │
│                                         │
│             [ Iniciar sesión ]          │
│  Crear perfil local                     │
└─────────────────────────────────────────┘
```

En el primer inicio se reemplaza el selector por el formulario de creación del perfil administrador. La recuperación de clave debe explicar las limitaciones definidas por la política de cifrado local.

### 3.2 Resumen

**Objetivo:** entender rápidamente cuánto se ha gastado en el periodo.

```text
┌────────────────────────────────────────────────────────────────────┐
│ Resumen         [ Hoy ▾ ] [‹] 5 nov 2026 [›]    [+ Nuevo gasto]    │
│                                                                    │
│  Ingresos del mes        Gastos del mes         Saldo disponible   │
│  $ 2.500.000 COP          $ 245.000 COP          $ 2.255.000 COP     │
│                                                                    │
│  Gastos por categoría                  Evolución del gasto          │
│  [gráfico con leyenda]                 [gráfico por día/semana]      │
│                                                                    │
│  Gastos recientes                                          Ver todos│
│  Fecha   Nombre                  Categoría           Valor          │
└────────────────────────────────────────────────────────────────────┘
```

El selector de periodo ofrecerá hoy, esta semana, este mes, este año y rango personalizado. El rango seleccionado se mantendrá al pasar al listado de gastos.

### 3.3 Lista de gastos

```text
┌────────────────────────────────────────────────────────────────────┐
│ Gastos                                      [+ Nuevo gasto]         │
│ [Buscar nombre o comercio...]  [Fechas ▾] [Categoría ▾] [Pago ▾]   │
│                                                                    │
│ Fecha       Nombre              Categoría       Método       Valor │
│ 05 nov      Mercado semanal     Compras         Débito       $ ... │
│ 04 nov      Internet casa       Servicios       Transfer.    $ ... │
│                                                                    │
│ [Anterior]                                      Página 1 de N [Sig.]│
└────────────────────────────────────────────────────────────────────┘
```

### 3.3.1 Ingresos

La pantalla de ingresos tendrá búsqueda y una lista con fecha, nombre, origen y valor. Permitirá crear, editar y mover ingresos a la papelera. El saldo disponible será la suma acumulada de ingresos menos gastos activos; al enviar un movimiento a la papelera se recalculará. Se permitirán saldos negativos.

El formulario de ingreso pedirá nombre, valor, fecha y permitirá añadir origen y nota. Para incorporar fondos existentes al empezar, se podrá registrar “Saldo inicial”.

Al abrir una fila se muestra el detalle y sus adjuntos. Las acciones incluyen editar y mover a papelera. El listado no incluye elementos de la papelera.

### 3.4 Crear o editar gasto

Formulario en panel lateral o diálogo amplio para conservar el contexto del listado.

```text
┌──────────────────────────────────────────────┐
│ Nuevo gasto                            [×]   │
│ Nombre *       [                            ]│
│ Valor COP *    [                            ]│
│ Fecha *        [ hoy             📅 ]        │
│ Categoría *    [ Seleccionar       ▾ ]       │
│ Método de pago [ Seleccionar       ▾ ]       │
│ Comercio       [                            ]│
│ Nota           [                            ]│
│ Adjuntos       [ Añadir archivo ]            │
│                                              │
│ [Leer recibo]          [Cancelar] [Guardar]  │
└──────────────────────────────────────────────┘
```

El formulario validará valores mayores que cero, campos requeridos y categoría activa. Al guardar desde OCR se conservará la procedencia como “reconocido y confirmado”.

### 3.5 Reconocimiento y revisión OCR

1. **Seleccionar:** elegir imagen o PDF. Mostrar formatos, tamaño y páginas permitidas.
2. **Confirmar envío:** explicar que el documento se enviará al servicio externo; botones “Enviar para reconocer” y “Cancelar”.
3. **Procesar:** mostrar estado y permitir cancelar si el proveedor lo admite.
4. **Revisar:** mostrar el recibo y los campos sugeridos lado a lado.

```text
┌────────────────────────────────────────────────────────────────┐
│ Revisa los datos detectados                                    │
│                                                                │
│ [Vista del documento]       Comercio       [                    ]│
│                             Fecha          [                    ]│
│                             Total COP      [                    ]│
│                             Impuestos      [                    ]│
│                             Nombre *       [                    ]│
│                             Categoría *    [ Seleccionar     ▾ ]│
│                                                                │
│ El reconocimiento puede equivocarse. Revisa el total.          │
│                 [Volver] [Guardar gasto]                       │
└────────────────────────────────────────────────────────────────┘
```

Si la detección falla, ofrecer “Completar manualmente” conservando el formulario. No mostrar una confianza numérica salvo que el proveedor exponga un valor interpretable y se defina su significado.

### 3.6 Informes

```text
┌────────────────────────────────────────────────────────────────────┐
│ Informes                                                           │
│ [Diario] [Semanal] [Mensual] [Anual] [Personalizado]                │
│ Periodo: [01 nov 2026] a [30 nov 2026]  [Categoría ▾] [Pago ▾]     │
│                                                                    │
│ Total: $ ... COP       Cantidad: ...       Promedio diario: $ ...  │
│ [Gráfico por categoría]            [Gráfico de evolución]           │
│ Detalle de gastos y totales por categoría                          │
│                                                                    │
│                         [PDF ▾] [CSV] [Excel]                      │
└────────────────────────────────────────────────────────────────────┘
```

Al exportar, se usará el mismo periodo y filtros visibles. La aplicación permitirá elegir nombre y ubicación del archivo.

### 3.7 Categorías y métodos de pago

Listado con nombre, color o ícono, cantidad de gastos asociados y estado. Acciones: crear, renombrar, cambiar orden y archivar. Si hay registros históricos, se explicará que archivar conserva sus datos.

### 3.8 Papelera

Listado con fecha de eliminación, nombre, categoría, valor y perfil que lo eliminó. Acciones: restaurar y eliminar definitivamente. La eliminación definitiva requiere confirmación y debe indicar que el elemento no se incluirá en futuros respaldos.

### 3.9 Copias de seguridad

- “Crear copia”: indica ubicación elegida, fecha, perfil o perfiles incluidos y tamaño aproximado.
- “Restaurar copia”: selecciona archivo, valida su integridad, muestra fecha y versión, solicita confirmación y crea una copia de seguridad del estado actual antes de restaurar.
- Mostrar resultado de manera explícita y mantener la aplicación utilizable si la operación falla.

### 3.10 Perfiles y preferencias

- Crear, renombrar, bloquear o desactivar perfiles locales.
- Cambiar clave y cerrar sesión.
- Configurar bloqueo por inactividad (10 minutos inicialmente).
- Configurar preferencias de formato e idioma; español de Colombia y COP por defecto.
- Configurar copias y revisar información de privacidad de OCR.
- Eliminar un perfil debe explicar qué pasa con sus gastos y adjuntos; no se borrará sin confirmación.

## 4. Estados comunes

- **Sin gastos:** sugerir registrar el primer gasto y crear categorías propias.
- **Sin resultados:** permitir limpiar filtros.
- **Sin conexión:** indicar que OCR no está disponible; mantener registro y consulta local.
- **OCR sin resultado:** ofrecer corrección manual.
- **Guardado:** confirmar que el gasto quedó registrado y permitir volver al listado.
- **Error de archivo:** indicar si el adjunto no existe o no se puede abrir sin perder los demás datos.
- **Carga larga:** mostrar progreso en OCR, exportación y respaldo cuando aplique.

## 5. Accesibilidad y uso con teclado

- Todas las acciones estarán disponibles mediante teclado, con foco visible.
- Campos con etiqueta persistente y errores junto al campo afectado.
- Gráficos acompañados de leyendas, valores resumidos y alternativa tabular.
- Botones de eliminación y estados de papelera con texto explícito.
- Contraste suficiente y estados que no dependan solo de colores.

## 6. Ajustes si se elige un libro compartido

Si los perfiles comparten gastos:

- La pantalla de inicio y la barra superior seguirán identificando el perfil activo.
- El resumen y los informes mostrarán a todas las personas del libro.
- La lista permitirá filtrar por “Registrado por”.
- Cada detalle mostrará quién creó y quién modificó el gasto.
- Se añadirá selección de libro si existe más de uno.

La estructura de pantallas no cambia de forma amplia; se agregan el filtro y la identificación del autor. Mientras esta decisión siga pendiente, el diseño usa un libro privado por perfil.

