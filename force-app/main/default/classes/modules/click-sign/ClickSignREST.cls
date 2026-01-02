@RestResource(urlMapping='/clicksign-update/*')
global without sharing class ClickSignREST {

    private static final String SECRET_KEY = '58a75003d36ccb8acfb9482436084784';

    @HttpPost
    global static String updateRecords() {

        String requestBody = RestContext.request.requestBody.toString();

        String receivedSignature = RestContext.request.headers.get('Content-Hmac');

        try{
            if (String.isEmpty(receivedSignature)) {
                //RestContext.response.statusCode = 400;
                //return 'Assinatura ausente';
            }
    
            // Calcular a assinatura HMAC SHA256
            String calculatedSignature = calculateHMAC(requestBody, SECRET_KEY);
    
            // Comparar a assinatura recebida com a calculada
            if (!receivedSignature.equals(calculatedSignature)) {
                //RestContext.response.statusCode = 401; // Unauthorized
                //return 'Assinatura inválida';
            }
                
            // Processa o conteúdo do body (exemplo: JSON)
            ClickSignInboundDTO dto = (ClickSignInboundDTO) JSON.deserialize(requestBody, ClickSignInboundDTO.class);

            List<ContentVersion> versions = [SELECT Id, ContentDocumentId, Title, PathOnClient, ExternalId__c, ClickSignEnvelope__c FROM ContentVersion WHERE ExternalId__c = :dto.document.key];

            ContentVersion currentVersion = versions[0];
                
            if(dto.event.name == 'sign'){
                
                Log__c lg = new Log__c(
                    Class__c  = 'ClickSignRest',
                    Method__c = 'update',
                    RequestBody__c = requestBody 
                );
                insert lg;

                ClickSignSigner__c signer = [SELECT Id, Status__c FROM ClickSignSigner__c WHERE ExternalId__c = :dto.event.data.signer.key];
                signer.Status__c = 'Assinado';
                update signer;
    
            }else if(dto.event.name == 'auto_close'){
                
                Log__c lg = new Log__c(
                    Class__c  = 'ClickSignRest',
                    Method__c = 'update',
                    RequestBody__c = requestBody 
                );
                insert lg;
    
                ClickSign__c clickSign = [SELECT Id, ClickSignEnvelope__c, RecordId__c FROM ClickSign__c WHERE ClickSignEnvelope__c = :currentVersion.ClickSignEnvelope__c];
    
                clickSign.Status__c = 'Document Assign';
                update clickSign;
                
                update new ClickSignEnvelope__c(
                    Id = clickSign.ClickSignEnvelope__c,
                    Status__c = 'Concluído'
                );
            }else if(dto.event.name == 'document_closed'){
                
                Http http = new Http();
                HttpRequest request = new HttpRequest();
    
                request.setEndpoint(dto.document.downloads.signed_file_url);
                request.setMethod('GET');
                request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                request.setTimeout(120000);
    
                HttpResponse response = http.send(request);
    
                Blob file = response.getBodyAsBlob();
                System.debug('file: ' + file);
    
                if(versions?.isEmpty()) return 'Documento não encontrado: '  + dto.document.key + ' ' + versions;
    
                ClickSign__c clickSign = [SELECT Id, ClickSignEnvelope__c, RecordId__c FROM ClickSign__c WHERE ClickSignEnvelope__c = :currentVersion.ClickSignEnvelope__c];
    
                // Criar nova versão do arquivo
                ContentVersion newVersion = new ContentVersion(
                    ContentDocumentId = currentVersion.ContentDocumentId,
                    VersionData = file,
                    Title = currentVersion.Title + '_signed.pdf',
                    PathOnClient = currentVersion.Title.replace('docx', 'pdf'),
                    ExternalId__c =  currentVersion.ExternalId__c
                );
                
                Log__c lg = new Log__c(
                    Class__c  = 'ClickSignRest',
                    Method__c = 'update',
                    RequestBody__c = requestBody 
                );
                insert lg;
    
                // Inserir a nova versão
                currentVersion.ExternalId__c = currentVersion.ExternalId__c + '_original';
                update currentVersion;
                
                insert newVersion;
    
                newVersion = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :newVersion.Id];
    
                // Criar link entre documento e envelope
                ContentDocumentLink newLink = new ContentDocumentLink(
                    ContentDocumentId = newVersion.ContentDocumentId,
                    LinkedEntityId = clickSign.RecordId__c
                );
    
                insert newLink;
            }
    
            return 'Registros atualizados com sucesso';
        }catch(Exception ex){
            Log__c lg = new Log__c(
                Class__c  = 'ClickSignRest',
                Method__c = 'update',
                RequestBody__c = requestBody 
            );
            insert lg;
            return ex.getMessage() + ' ' + String.valueOf(ex.getLineNumber());
        }
        
    }

    private static String calculateHMAC(String data, String key) {
        Blob mac = Crypto.generateMac('HMACSHA256', Blob.valueOf(data), Blob.valueOf(key));
        return EncodingUtil.base64Encode(mac); // Codificação base64 (alterar conforme necessário)
    }
}