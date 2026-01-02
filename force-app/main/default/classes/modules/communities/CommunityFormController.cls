// Apex Class: CommunityFormController (Updated)
public without sharing class CommunityFormController {
    @AuraEnabled
    public static Id createCase(String payload) {
        Map<String, Object> formData = (Map<String, Object>) JSON.deserializeUntyped(payload);
        System.debug('Payload: ' + payload);
        System.debug('Form Data: ' + formData);

        Id queueId = getQueueIdByName('Qualificação de Integradores');

        // Create a Contact record with Integrador information
        Contact integradorContact = new Contact();
        integradorContact.LastName = (String) formData.get('nomeRepresentante');
        integradorContact.Email = (String) formData.get('email');
        integradorContact.Phone = (String) formData.get('telefone');
        integradorContact.MailingState = (String) formData.get('estado');
        integradorContact.MailingCity = (String) formData.get('cidade');
        integradorContact.MailingStreet = (String) formData.get('endereco');
        integradorContact.MailingPostalCode = (String) formData.get('cep');
        integradorContact.MailingCountry = 'Brasil';

        insert integradorContact;

        // Define all fields and ensure they are present in formData
        Case caseRecord = new Case();
        caseRecord.Description = (String) formData.get('mensagem');
        caseRecord.Subject = 'Integrador - ' + (String) formData.get('razaoSocial');
        caseRecord.Status = 'Novo';
        caseRecord.RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Qualificação de Integradores').getRecordTypeId();
        caseRecord.OwnerId = queueId == null ? UserInfo.getUserId() : queueId;
        // Map fields to Case object
        caseRecord.NomeIntegradorWeb__c = (String) formData.get('nomeFantasia');
        caseRecord.EmailIntegradorWeb__c = (String) formData.get('email');
        caseRecord.SuppliedPhone = (String) formData.get('telefone');
        caseRecord.Estado__c = (String) formData.get('estado');
        caseRecord.Cidade__c = (String) formData.get('cidade');
        caseRecord.NomeConsultorWeb__c = (String) formData.get('nomeConsultor');
        caseRecord.EmailConsultorWeb__c = (String) formData.get('emailConsultor');
        caseRecord.DesejaSeTornarConsultor__c = formData.get('beConsultant') == 'true' ? true : false;
        caseRecord.EmailConsultorWeb__c = (String)  formData.get('emailConsult');
        caseRecord.DesejaSeTornarConsultor__c = formData.get('tornarConsultor') == 'true' ? true : false;
        caseRecord.PaisIntegrador__c = 'Brasil';
        
        // Additional fields from formData
        caseRecord.CNPJ__c = (String) formData.get('cnpj');
        caseRecord.RazaoSocial__c = (String) formData.get('razaoSocial');
        caseRecord.NomeFantasia__c = (String) formData.get('nomeFantasia');
        caseRecord.Endereco__c = (String) formData.get('endereco');
        caseRecord.Bairro__c = (String) formData.get('bairro');
        caseRecord.CEP__c = (String) formData.get('cep');
        caseRecord.Contactid = integradorContact.Id;

        // Representante Legal fields
        caseRecord.NomeRepresentante__c = (String) formData.get('nomeRepresentante');
        caseRecord.EnderecoRepresentante__c = (String) formData.get('enderecoRepresentante');
        caseRecord.BairroRepresentante__c = (String) formData.get('bairroRepresentante');
        caseRecord.CidadeRepresentante__c = (String) formData.get('cidadeRepresentante');
        caseRecord.ComplementoRepresentante__c = (String) formData.get('complementoRepresentante');
        caseRecord.EstadoRepresentante__c = (String) formData.get('estadoRepresentante');
        caseRecord.CEPRepresentante__c = (String) formData.get('cepRepresentante');
        caseRecord.TelefoneRepresentante__c = (String) formData.get('telefoneRepresentante');
        caseRecord.EmailRepresentante__c = (String) formData.get('emailRepresentante');
        caseRecord.CPFRepresentante__c = (String) formData.get('cpfRepresentante');

        // Dados Bancários fields
        caseRecord.Banco__c = (String) formData.get('banco');
        caseRecord.Agencia__c = (String) formData.get('agencia');
        caseRecord.ContaCorrente__c = (String) formData.get('contaCorrente');
        
        caseRecord.CertidaoNegativaTrabalhista__c = (String) formData.get('certidaoTrabalhista');
        caseRecord.CertidaoNegativaCivel__c = (String) formData.get('certidaoCivel');
        caseRecord.CertidaoNegativaCriminal__c = (String) formData.get('certidaoCriminal');
        caseRecord.CertidaoNegativaFederal__c = (String) formData.get('certidaoFederal');
        caseRecord.ContratoSocialUltimaAlteracao__c = (String) formData.get('contratoSocial');
        caseRecord.DocPessoais_Socios_Representantes__c = (String) formData.get('docPessoais');
        caseRecord.PortfolioEmpresa__c = (String) formData.get('portfolioEmpresa');
        caseRecord.FotosInstalacoes__c = (String) formData.get('fotosInstalacoes');
        
        insert caseRecord;
        return caseRecord.Id;
    }

    @AuraEnabled
    public static Id saveFile(Map<String, Object> fileDataMap, Id caseId) {
        FileInfo fileData = new FileInfo();
        fileData.Title = (String) fileDataMap.get('name');
        fileData.VersionData = (String) fileDataMap.get('content');
        System.debug('File Data: ' + JSON.serialize(fileData));

        ContentVersion objCntVersion = new ContentVersion();
        objCntVersion.PathOnClient = fileData.Title;
        objCntVersion.Title = fileData.Title;
        objCntVersion.VersionData = EncodingUtil.base64Decode(fileData.VersionData); // Convert to Blob
        insert objCntVersion;

        return objCntVersion.Id;
    }

    @AuraEnabled
    public static void createContentVersion(List<Id> contentVersionId, Id linkedEntityId) {
        createContentVersionAsync(contentVersionId, linkedEntityId);
    }

    @future
    private static void createContentVersionAsync(List<Id> contentVersionId, Id linkedEntityId) {
        for (Id versionId : contentVersionId) {
            ContentVersion version = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :versionId LIMIT 1];
            if (version != null) {
                ContentDocumentLink link = new ContentDocumentLink();
                link.ContentDocumentId = version.ContentDocumentId;
                link.LinkedEntityId = linkedEntityId;
                link.Visibility = 'AllUsers';
                link.ShareType = 'V';
                insert link;
            } else {
                System.debug('ContentVersion not found for ID: ' + versionId);
            }
        }
    }

    public class FileInfo {
        public String Title;
        public String VersionData;
    }

    public static Id getQueueIdByName(String queueName) {
        Group queue = [SELECT Id FROM Group WHERE Name = :queueName AND Type = 'Queue' LIMIT 1];
        return queue != null ? queue.Id : null;
    }

}