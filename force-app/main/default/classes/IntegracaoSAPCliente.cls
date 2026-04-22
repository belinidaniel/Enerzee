/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-18-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoSAPClienteTest
 **/
public with sharing class IntegracaoSAPCliente implements Queueable, Database.AllowsCallouts {
  private final Set<Id> recordIds;

  public IntegracaoSAPCliente(Set<Id> recordIds) {
    this.recordIds = recordIds;
  }

  public void execute(QueueableContext ctx) {
    List<Account> accountList = [
      SELECT
        Id,
        IdVirtualOffice__c,
        CPF__c,
        CNPJ__c,
        Description,
        SeCPFouCNPJ__c,
        Name,
        Type,
        Email__c,
        Phone,
        BillingStreet,
        BillingPostalCode,
        BillingCity,
        BillingCountry,
        BillingState,
        BillingAddress,
        BairroCobranca__c,
        MunicipioCobranca__c,
        ComplementoCobranca__c,
        NumeroRuaCobranca__c,
        ShippingStreet,
        ShippingPostalCode,
        ShippingCity,
        ShippingCountry,
        ShippingState,
        ShippingAddress,
        BairroEntrega__c,
        MunicipioEntrega__c,
        ComplementoEntrega__c,
        NumeroRuaEntrega__c,
        SucessoIntegracaoSAP__c,
        StatusBodyIntegracaoSAP__c
      FROM Account
      WHERE Id IN :recordIds
      WITH SECURITY_ENFORCED
    ];

    SAPIntegrationService.EndpointConfig sapConfig = SAPIntegrationService.resolveConfig(
      'ClienteSAP'
    );

    for (Account acc : accountList) {
      String docValue = acc.SeCPFouCNPJ__c;
      ClienteRequest corpoRequisicao = new ClienteRequest();
      corpoRequisicao.CardCode = docValue;
      corpoRequisicao.CardName = acc.Name;
      corpoRequisicao.CardType = 'cCustomer';
      corpoRequisicao.EmailAddress = acc.Email__c;
      corpoRequisicao.Phone1 = acc.Phone;
      corpoRequisicao.FederalTaxID = docValue;
      corpoRequisicao.BPAddresses = new List<SAPBusinessPartnerMapper.BPAddress>{};
      corpoRequisicao.BPFiscalTaxIDCollection = new List<SAPBusinessPartnerMapper.BPFiscalTaxID>{};

      if (acc.BillingAddress != null) {
        corpoRequisicao.BPAddresses.add(
          SAPBusinessPartnerMapper.buildBillingAddress(
            docValue,
            acc.BillingStreet,
            acc.NumeroRuaCobranca__c,
            acc.BairroCobranca__c,
            acc.BillingPostalCode,
            acc.BillingCity,
            acc.BillingCity,
            SAPBusinessPartnerMapper.normalizeCountry(acc.BillingCountry),
            SAPBusinessPartnerMapper.normalizeState(acc.BillingState),
            acc.ComplementoCobranca__c
          )
        );
      }

      if (acc.ShippingAddress != null) {
        corpoRequisicao.BPAddresses.add(
          SAPBusinessPartnerMapper.buildShippingAddress(
            docValue,
            acc.ShippingStreet,
            acc.NumeroRuaEntrega__c,
            acc.BairroEntrega__c,
            acc.ShippingPostalCode,
            acc.ShippingCity,
            acc.BillingCity,
            SAPBusinessPartnerMapper.normalizeCountry(acc.ShippingCountry),
            SAPBusinessPartnerMapper.normalizeState(acc.ShippingState),
            acc.ComplementoEntrega__c
          )
        );
      }

      corpoRequisicao.BPFiscalTaxIDCollection.add(
        SAPBusinessPartnerMapper.buildFiscalTaxId(
          acc.CPF__c,
          acc.CNPJ__c,
          docValue
        )
      );

      try {
        String requestBody = JSON.serialize(corpoRequisicao);
        System.debug(
          LoggingLevel.ERROR,
          'IntegracaoSAPCliente request body: ' + requestBody
        );
        HttpResponse response = SAPIntegrationService.post(
          requestBody,
          sapConfig,
          null
        );
        Utils.createLog(
          'IntegracaoSAPCliente',
          'sendCliente ' + acc.Id,
          response
        );

        if (response.getBody() != null && response.getBody() != '') {
          Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
          );
          Integer statusCode = Integer.valueOf(responseBody.get('codigoHttp'));
          acc.SucessoIntegracaoSAP__c = SAPIntegrationService.isSuccess(
            statusCode
          );
          acc.StatusBodyIntegracaoSAP__c =
            statusCode +
            ' ' +
            response.getBody() +
            ' ' +
            response.getStatus();
        }
      } catch (Exception e) {
        Utils.createLog('IntegracaoSAPCliente', 'sendCliente ' + acc.Id, e);
        acc.SucessoIntegracaoSAP__c = false;
        acc.StatusBodyIntegracaoSAP__c =
          e.getMessage() +
          ' ' +
          e.getStackTraceString();
      }
    }

    AccountTriggerHandler.disableTrigger();
    try {
      update accountList;
    } finally {
      AccountTriggerHandler.enableTrigger();
    }
  }

  public class ClienteRequest {
    public String CardCode;
    public String CardName;
    public String CardType;
    public String EmailAddress;
    public String Phone1;
    public String FederalTaxID;
    public SAPBusinessPartnerMapper.BPAddress[] BPAddresses;
    public SAPBusinessPartnerMapper.BPFiscalTaxID[] BPFiscalTaxIDCollection;
  }
}
