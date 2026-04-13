# Spec Técnica — Chunked Upload para Geração de Proposta

**Contexto:** O Salesforce Apex tem limite de 6MB para manipulação de String em memória,  
o que impede o envio de arquivos `.pptx` grandes (5.9MB e 13MB) via multipart em um único request.  
A solução é substituir o upload direto do arquivo por um fluxo de 3 etapas: init → chunks → finalize.

---

## Base URL

```
https://enerzeeapifile.livelybeach-f3e8beac.brazilsouth.azurecontainerapps.io
```

---

## Fluxo Completo

```
1. POST /convertProposal/init      → registra sessão, recebe uploadId
2. POST /convertProposal/chunk     → envia N partes binárias do arquivo (loop)
3. POST /convertProposal/finalize  → API remonta arquivo, processa com tags/sections, retorna PDF
```

---

## Endpoint 1 — Iniciar Upload

### Request

```
POST /convertProposal/init
Content-Type: application/json
```

```json
{
  "fileName": "Proposta_Template.pptx",
  "mimeType": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "totalChunks": 3,
  "tags": {
    "{{NomeConta}}": "João Silva",
    "{{ValorTotalProposta}}": "85.000,00",
    "{{Observacoes}}": "- Texto de observação..."
  },
  "sections_to_show": ["Proposta", "Proposta de valores", "Rodape da proposta"]
}
```

| Campo              | Tipo          | Obrigatório | Descrição                                  |
| ------------------ | ------------- | ----------- | ------------------------------------------ |
| `fileName`         | string        | sim         | Nome do arquivo com extensão               |
| `mimeType`         | string        | sim         | MIME type do arquivo                       |
| `totalChunks`      | integer       | sim         | Número total de partes que serão enviadas  |
| `tags`             | object        | sim         | Mapa de tags para substituição no template |
| `sections_to_show` | array[string] | sim         | Nomes das seções a exibir no PDF           |

### Response `200 OK`

```json
{
  "uploadId": "550e8400-e29b-41d4-a716-446655440000",
  "expiresAt": "2026-04-13T14:00:00Z"
}
```

| Campo       | Tipo              | Descrição                                                      |
| ----------- | ----------------- | -------------------------------------------------------------- |
| `uploadId`  | string (UUID)     | Identificador da sessão de upload — usar nos próximos requests |
| `expiresAt` | string (ISO 8601) | Tempo máximo para completar o upload (recomendado: 10 minutos) |

### Erros

| Status | Código                 | Descrição                                       |
| ------ | ---------------------- | ----------------------------------------------- |
| `400`  | `INVALID_PAYLOAD`      | Campo obrigatório ausente ou inválido           |
| `422`  | `INVALID_TOTAL_CHUNKS` | `totalChunks` <= 0 ou acima do limite permitido |

---

## Endpoint 2 — Enviar Chunk

### Request

```
POST /convertProposal/chunk
Content-Type: multipart/form-data
```

| Campo (form-data) | Tipo    | Obrigatório | Descrição                           |
| ----------------- | ------- | ----------- | ----------------------------------- |
| `uploadId`        | string  | sim         | UUID retornado pelo `/init`         |
| `partNumber`      | integer | sim         | Número da parte, começando em **1** |
| `chunk`           | binary  | sim         | Bytes desta parte do arquivo        |

**Exemplo curl:**

```bash
curl -X POST \
  https://.../convertProposal/chunk \
  -F "uploadId=550e8400-e29b-41d4-a716-446655440000" \
  -F "partNumber=1" \
  -F "chunk=@parte1.bin"
```

**Tamanho máximo por chunk:** 3MB (3.145.728 bytes)  
**Ordem de envio:** partes podem chegar fora de ordem — a API remonta pelo `partNumber`

### Response `200 OK`

```json
{
  "uploadId": "550e8400-e29b-41d4-a716-446655440000",
  "partNumber": 1,
  "received": true
}
```

### Erros

| Status | Código                   | Descrição                                                   |
| ------ | ------------------------ | ----------------------------------------------------------- |
| `404`  | `UPLOAD_NOT_FOUND`       | `uploadId` inválido ou sessão expirada                      |
| `409`  | `CHUNK_ALREADY_RECEIVED` | Chunk com esse `partNumber` já foi recebido                 |
| `413`  | `CHUNK_TOO_LARGE`        | Parte excede 3MB                                            |
| `400`  | `INVALID_PART_NUMBER`    | `partNumber` fora do intervalo esperado (1 a `totalChunks`) |

---

## Endpoint 3 — Finalizar e Gerar PDF

### Request

```
POST /convertProposal/finalize
Content-Type: application/json
```

```json
{
  "uploadId": "550e8400-e29b-41d4-a716-446655440000"
}
```

| Campo      | Tipo   | Obrigatório | Descrição                          |
| ---------- | ------ | ----------- | ---------------------------------- |
| `uploadId` | string | sim         | UUID da sessão iniciada em `/init` |

### Response `200 OK`

```
Content-Type: application/pdf
Content-Disposition: attachment; filename="Proposta_B_PROP-2026-1183.pdf"
```

Body: **stream binário do PDF** (não JSON, não base64).

> **Motivo:** o Apex lê a resposta com `response.getBodyAsBlob()` — Blob não tem o limite de 6MB de String.  
> Retornar `fileBase64` em JSON criaria o mesmo problema do upload na volta: ~17MB de String → estouro de memória.  
> O stream binário é salvo direto como `ContentVersion` sem nenhuma decodificação adicional.

### Erros

| Status | Código                      | Descrição                                                 |
| ------ | --------------------------- | --------------------------------------------------------- |
| `404`  | `UPLOAD_NOT_FOUND`          | `uploadId` inválido ou sessão expirada                    |
| `409`  | `CHUNKS_INCOMPLETE`         | Nem todos os chunks foram recebidos ainda                 |
| `422`  | `TEMPLATE_PROCESSING_ERROR` | Erro ao processar o `.pptx` com as tags/seções fornecidas |
| `500`  | `INTERNAL_ERROR`            | Erro inesperado — logar e retornar mensagem genérica      |

---

## Como o Salesforce consome o `/finalize`

```apex
HttpResponse response = new Http().send(request);
// Lê direto como Blob — sem passar por String, sem limite de 6MB
Blob pdfBlob = response.getBodyAsBlob();
// Salva como ContentVersion no Salesforce
```

Não é necessário nenhum parsing de JSON na resposta. O Apex lê o body binário direto e persiste.

---

## Regras de Negócio da API

### Remontagem do arquivo

- A API deve remontar os chunks na ordem do `partNumber` (1 → N)
- A validação de completude deve checar se todos os `partNumber` de 1 a `totalChunks` foram recebidos
- Chunks podem chegar fora de ordem — armazenar em buffer por `uploadId + partNumber`

### Processamento do template

- O arquivo remontado é o `.pptx` original
- As `tags` fornecidas no `/init` são substituídas no template (mesmo comportamento atual do `POST /convertProposal`)
- As `sections_to_show` controlam quais seções do arquivo serão incluídas no PDF gerado
- O PDF resultante deve ser retornado em Base64 no campo `fileBase64`

### Sessão e expiração

- Sessões não finalizadas dentro do `expiresAt` devem ser descartadas automaticamente
- Chunks de sessões expiradas devem retornar `404 UPLOAD_NOT_FOUND`
- Recomendação: TTL de 10 minutos após o `/init`

### Limpeza

- Após o `/finalize` bem-sucedido, a sessão e os chunks podem ser descartados da memória/storage

---

## Exemplo de Fluxo Completo (curl)

```bash
# 1. Init
RESPONSE=$(curl -s -X POST https://.../convertProposal/init \
  -H "Content-Type: application/json" \
  -d '{
    "fileName": "Proposta_Template.pptx",
    "mimeType": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "totalChunks": 2,
    "tags": { "{{NomeConta}}": "Empresa XYZ", "{{ValorTotalProposta}}": "120.000,00" },
    "sections_to_show": ["Proposta", "Proposta de valores", "Rodape da proposta"]
  }')

UPLOAD_ID=$(echo $RESPONSE | jq -r '.uploadId')
echo "uploadId: $UPLOAD_ID"

# 2. Split do arquivo em partes de 3MB e envio
split -b 3145728 Proposta_Template.pptx parte_
PART=1
for FILE in parte_*; do
  curl -s -X POST https://.../convertProposal/chunk \
    -F "uploadId=$UPLOAD_ID" \
    -F "partNumber=$PART" \
    -F "chunk=@$FILE"
  PART=$((PART + 1))
done

# 3. Finalize — recebe PDF em base64
curl -s -X POST https://.../convertProposal/finalize \
  -H "Content-Type: application/json" \
  -d "{\"uploadId\": \"$UPLOAD_ID\"}" \
  | jq -r '.fileBase64' | base64 --decode > proposta_gerada.pdf

echo "PDF gerado: proposta_gerada.pdf"
```

---

## Diagrama de Sequência

```
Salesforce Apex          API Service              Storage (memória/temp)
     │                       │                           │
     │── POST /init ─────────▶│                           │
     │   { fileName,          │── salva sessão ──────────▶│
     │     totalChunks,       │   { uploadId, tags,       │
     │     tags, sections }   │     sections, chunks:[] } │
     │◀── { uploadId } ───────│                           │
     │                        │                           │
     │── POST /chunk (1) ─────▶│                           │
     │   { uploadId, part=1,  │── armazena chunk 1 ──────▶│
     │     chunk: binary }    │                           │
     │◀── { received: true } ─│                           │
     │                        │                           │
     │── POST /chunk (2) ─────▶│                           │
     │◀── { received: true } ─│                           │
     │                        │                           │
     │── POST /finalize ──────▶│                           │
     │   { uploadId }         │── busca sessão + chunks ──▶│
     │                        │◀── retorna tudo ───────────│
     │                        │── remonta arquivo .pptx    │
     │                        │── substitui tags           │
     │                        │── filtra seções            │
     │                        │── converte para PDF        │
     │◀── { fileBase64 } ─────│                           │
     │                        │── limpa sessão ───────────▶│
```

---

## Notas de Implementação

- **Storage dos chunks:** pode ser memória (para arquivos pequenos/médio) ou disco temporário. Para produção com múltiplas instâncias, usar Redis ou Azure Blob Storage com TTL
- **Chunk size no cliente (Salesforce):** será de ~2.25MB de bytes (3MB de base64 ÷ 1.33) para respeitar o limite de String do Apex
- **Idempotência no `/chunk`:** se o mesmo `partNumber` chegar duas vezes com o mesmo conteúdo, aceitar e retornar `200`. Se conteúdo diferente, retornar `409`
- **Backward compatibility:** o endpoint original `POST /convertProposal` pode ser mantido para clientes menores ou testes, mas deve ser depreciado a médio prazo
- **Response do `/finalize`:** retornar `Content-Type: application/pdf` + stream binário. **Não usar JSON com base64** — o Apex não consegue ler strings de ~17MB sem estourar memória
