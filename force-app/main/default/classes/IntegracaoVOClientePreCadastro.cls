/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 02-05-2026
 * @last modified by  : Daniel Belini
**/
public with sharing class IntegracaoVOClientePreCadastro {

    @future(callout=true)
    public static void sendCliente(Set<Id> triggerIds){
        List<Account> accountList = [
            SELECT  Id, Name, Email__c, DataNascimento__c, SeCPFouCNPJ__c, Consultor__r.Login_no_virtual__c, Consultor__r.IdVirtualOffice2__c, ShippingStreet, NumeroRuaEntrega__c, ShippingPostalCode, ComplementoEntrega__c
            FROM    Account
            WHERE   Id IN :triggerIds AND IdVirtualOffice2__c = null
        ];

        if(accountList.isEmpty()){
            return;
        }

        processAccounts(accountList, 'sendCliente');
    }

    public static void processAccounts(List<Account> accountList, String logContext){
        if(accountList == null || accountList.isEmpty()){
            return;
        }

        for (Account acc : accountList) {
            ClientRequest corpoRequisicao = new ClientRequest();
            corpoRequisicao.IdAccountSalesForce	= acc.Id;
            corpoRequisicao.NomeCompleto        = acc.Name;
            corpoRequisicao.email               = acc.Email__c;
            corpoRequisicao.DataNascimento      = acc.DataNascimento__c == null ? '2000-01-01' : String.valueOf(acc.DataNascimento__c);
            corpoRequisicao.Documento           = acc.SeCPFouCNPJ__c;
            corpoRequisicao.LoginUsuarioPai     = acc.Consultor__r.Login_no_virtual__c;
            
            if (acc.Consultor__r != null && acc.Consultor__r.IdVirtualOffice2__c != null) {
    			corpoRequisicao.IdUsuarioPai = Integer.valueOf(acc.Consultor__r.IdVirtualOffice2__c);
			}
    
            BPAddress bpAddress = new BPAddress();
            bpAddress.Rua           = acc.ShippingStreet;
            bpAddress.Numero        = acc.NumeroRuaEntrega__c;
            bpAddress.Cep           = acc.ShippingPostalCode;
            bpAddress.Complemento   = acc.ComplementoEntrega__c;
    
            corpoRequisicao.Endereco = bpAddress;
                
            try {
                HttpResponse response = chamadaIntegracao(JSON.serialize(corpoRequisicao), 'ClienteVO');
                System.debug('Response Status: ' + response.getStatusCode() + ' ' + response.getStatus());
                system.debug('Response Body: ' + response.getBody());

                Log__c logRecord = Utils.createLogNoInsert(
                    'IntegracaoVOClientePreCadastro',
                    logContext + ' ' + acc.Id,
                    response
                );

                if (response.getBody() != null && response.getBody() != '') {

                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    Boolean error = Boolean.valueOf(responseBody.get('erro'));

                    if (!error) {
                        String IdVirtualOffice = String.valueOf(responseBody.get('idusuario'));
                        acc.IdVirtualOffice2__c = IdVirtualOffice;
                        acc.LoginVirtualOffice__c = acc.Email__c;
                    } else {
                        String errorMessage = VOIntegrationEmailAlert.extractErrorMessage(
                            responseBody,
                            response.getBody()
                        );
                        VOIntegrationEmailAlert.sendError(
                            'Cliente VO',
                            acc.Name,
                            acc.Id,
                            errorMessage
                        );
                        logRecord.Erro_Enviado__c = true;
                    }

                    acc.SucessoIntegracaoVO__c = !error;
                    acc.StatusBodyIntegracaoVO__c = response.getStatusCode() + ' ' + response.getBody() + ' ' + response.getStatus();

                }

                insert logRecord;
                
            } catch (Exception e) {
                Log__c logRecord = Utils.createLogNoInsert(
                    'IntegracaoVOClientePreCadastro',
                    logContext + ' ' + acc.Id,
                    e
                );
                
                acc.SucessoIntegracaoVO__c = false;
                acc.StatusBodyIntegracaoVO__c = e.getMessage() + ' ' + e.getStackTraceString();

                VOIntegrationEmailAlert.sendError(
                    'Cliente VO',
                    acc.Name,
                    acc.Id,
                    e.getMessage()
                );

                logRecord.Erro_Enviado__c = true;
                insert logRecord;
            }
        }

        AccountTriggerHandler.disableTrigger();
        update accountList;
        AccountTriggerHandler.enableTrigger();
    }
            
    private static HttpResponse chamadaIntegracao(String body, String endpointName){
        Integrador__mdt parametrosIntegracao = [
            SELECT  Id, URL__c
            FROM    Integrador__mdt 
            WHERE   DeveloperName = :endpointName
            LIMIT 1
        ];
        
        if (parametrosIntegracao == null) {
            throw new IllegalArgumentException('Endpoint não encontrado para: ' + endpointName);
        }
    
        Http httpObj = new Http();
        HttpRequest request = new HttpRequest();
            
        request.setEndpoint(parametrosIntegracao.URL__c);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(body);
        
        return Utils.callIntegrationVO(request);
    }
    
    public class ClientRequest{
        public Id      	   IdAccountSalesForce;
        public String      NomeCompleto;
        public String      email;
        public String      DataNascimento;
        public String      Documento;
        public String      LoginUsuarioPai;
        public Integer     IdUsuarioPai;
        public BPAddress   Endereco;
    }
    
    public class BPAddress{
        public String  Rua;
        public String  Numero;
        public String  Cep;             
        public String  Complemento;                    
    }
    
}
