# Pasarela OCR

Servicio privado que recibe una imagen o PDF y consulta Google Document AI Expense Parser. No escribe el documento en disco ni incluye credenciales de Google en la aplicación. Configuración de Cloud Run pendiente.

## Configuración

Crear un procesador `Expense Parser` en un proyecto de Google Cloud, habilitar Document AI y facturación, y desplegar esta carpeta en Cloud Run con una cuenta de servicio que tenga solo permisos para procesar documentos. Definir estas variables en el servicio:

- `GOOGLE_CLOUD_PROJECT`: ID del proyecto de Google Cloud.
- `DOCUMENT_AI_PROCESSOR_ID`: ID del procesador Expense Parser.
- `DOCUMENT_AI_LOCATION`: ubicación elegida para el procesador, por ejemplo `us` o `eu`.
- `OCR_GATEWAY_TOKEN`: token privado para autorizar solicitudes.

La ubicación del host debe coincidir con la región del procesador. El endpoint de análisis es `POST /v1/receipt:analyze` y acepta JSON con `fileName`, `mimeType` y `contentBase64`. Responde `merchant`, `amountCents`, `currency`, `date` y `confidence`.

En la app, el endpoint HTTPS completo y el token se configuran al compilar mediante `OCR_GATEWAY_URL` y `OCR_GATEWAY_TOKEN`. El token incluido en una aplicación de escritorio se puede extraer del ejecutable; por eso esta configuración es solo para una prueba privada. Antes de distribuir el instalador a más personas habrá que añadir una identidad de usuario o tokens por dispositivo y límites de consumo en la pasarela.

## Costos y tratamiento del documento

Google publica USD 0,10 por cada solicitud de hasta 10 páginas del Expense Parser, sujeto a cambios y conversión de moneda. Las solicitudes síncronas admiten hasta 10 páginas para este procesador. Google indica que el contenido de solicitudes síncronas se procesa en memoria, cifrado durante el tránsito, sin guardarse en disco. La aplicación pide consentimiento antes de enviar el archivo. Fuentes: [precios](https://cloud.google.com/products/document-ai/pricing), [límites del procesador](https://docs.cloud.google.com/document-ai/docs/processors-list) y [seguridad y tratamiento](https://docs.cloud.google.com/document-ai/docs/security).
