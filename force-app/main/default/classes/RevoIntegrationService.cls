public class RevoIntegrationService {
    private static String cachedToken;

    @future(callout=true)
    public static void sendToCreditAnalysis(Id opportunityId) {
        Opportunity opp;

        try {
            // Recupera a oportunidade com o ID fornecido
            opp = [SELECT Id, ReferenceIdRevo__c, ErroIntegracaoRevo__c, IntegradoRevo__c 
                   FROM Opportunity 
                   WHERE Id = :opportunityId 
                   LIMIT 1];

            Map<String, Object> payload = new Map<String, Object>();
            payload.put('reference', opp.ReferenceIdRevo__c);
            String body = JSON.serialize(payload);
            System.debug('BODY --> ' + body);
            HttpResponse response = callIntegration(body, 'Revo_CreditAnalysis', 'POST');

            if (response != null && response.getStatusCode() == 200) {
                System.debug('Análise de crédito enviada com sucesso: ' + response.getBody());
                opp.IntegradoRevo__c = true;
                opp.ErroIntegracaoRevo__c = false;
            } else {
                //System.debug('Erro ao enviar para análise de crédito: ' + (response != null ? response.getBody() : 'Resposta nula'));
                Utils.createLog('RevoIntegrationService', 'Exception in sendToCreditAnalysis ' + opp.Id, response);
                opp.IntegradoRevo__c = false; 
                opp.ErroIntegracaoRevo__c = true;
            }
        } catch (Exception e) {
            System.debug('Erro na integração com a Revo: ' + e.getMessage());
            if (opp != null) {
                Utils.createLog('RevoIntegrationService', 'Exception in sendToCreditAnalysis ' + opp.Id, e.getMessage());
                opp.IntegradoRevo__c = true; 
                opp.ErroIntegracaoRevo__c = true;
            }
        }

        if (opp != null) {
            try {
                update opp;
            } catch (DmlException dmlEx) {
                System.debug('Erro ao atualizar a oportunidade: ' + dmlEx.getMessage());
            }
        }
    }

    private static HttpResponse callIntegration(String body, String integrationName, String method) {
        try {
            
            Integrador__mdt integrationParams = [
                SELECT URL__c, Login__c, senha__c, LastToken__c
                FROM Integrador__mdt
                WHERE DeveloperName = :integrationName
                LIMIT 1
            ];

            if (String.isBlank(integrationParams.URL__c)) {
                Utils.createLog('RevoIntegrationService', 'Exception in callIntegration', 
                                'URL não configurada para a integração: ' + integrationName);
                return null;
            }

            if (cachedToken == null && String.isBlank(integrationParams.LastToken__c)) {
                cachedToken = getNewToken();
            } else if (cachedToken == null) {
                cachedToken = integrationParams.LastToken__c;
            }

            HttpRequest request = new HttpRequest();
            request.setEndpoint(integrationParams.URL__c);
            request.setMethod(method);
            request.setHeader('Content-Type', 'application/json');
            if (!String.isBlank(cachedToken)) {
                request.setHeader('Authorization', 'Bearer ' + cachedToken);
            }
            request.setBody(body);

            System.debug('BODY -----> ' + body);
            System.debug('TOKEN ---->' + cachedToken);

            Http http = new Http();
            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 401) {
                System.debug('Token expirado, obtendo novo token...');
                cachedToken = getNewToken();
                request.setHeader('Authorization', 'Bearer ' + cachedToken);
                response = http.send(request);
            }

            return response;
        } catch (Exception e) {
            Utils.createLog('RevoIntegrationService', 'Exception in callIntegration', 
                            'Erro ao realizar a integração: ' + e.getMessage());
            return null;
        }
    }

    private static String getNewToken() {
        try {
            Integrador__mdt authParams = [
                SELECT URL__c, Login__c, senha__c
                FROM Integrador__mdt
                WHERE DeveloperName = 'Revo_Authentication'
                LIMIT 1
            ];

            if (String.isBlank(authParams.URL__c)) {
                Utils.createLog('RevoIntegrationService', 'Exception in getNewToken', 
                                'URL de autenticação não configurada.');
                return null;
            }

            String auth = EncodingUtil.base64Encode(Blob.valueOf(authParams.Login__c + ':' + authParams.senha__c));

            HttpRequest request = new HttpRequest();
            request.setEndpoint(authParams.URL__c);
            request.setMethod('POST');
            request.setHeader('Authorization', 'Basic ' + auth);
            request.setHeader('Content-Type', 'application/json');
            request.setBody('{}'); // Payload vazio

            Http http = new Http();
            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                List<Object> dataList = (List<Object>) responseMap.get('data');
                if (!dataList.isEmpty()) {
                    Map<String, Object> tokenData = (Map<String, Object>) dataList[0];
                    return (String) tokenData.get('token');
                } else {
                    return null;
                }
            } else {
                Utils.createLog('RevoIntegrationService', 'Exception in getNewToken', response);
                return null;
            }
        } catch (Exception e) {
            return null;
        }
    }
}