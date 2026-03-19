/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-18-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoSAPIntegradorTest
 **/
public with sharing class IntegracaoSAPIntegrador implements Queueable, Database.AllowsCallouts {
  private final Set<Id> recordIds;

  public IntegracaoSAPIntegrador(Set<Id> recordIds) {
    this.recordIds = recordIds;
  }

  public void execute(QueueableContext ctx) {
    List<Integradores__c> IntegradorList = [
      SELECT
        Id,
        CPF__c,
        CNPJ__c,
        SeCPFouCNPJ__c,
        Name,
        Email__c,
        Telefone__c,
        CEP__c,
        Cidade__c,
        Estado__c,
        Bairro__c,
        RazaoSocial__c,
        Logradouro__c,
        Complemento__c,
        Conta__c,
        Agencia__c,
        Banco__c
      FROM Integradores__c
      WHERE Id IN :recordIds
    ];

    SAPIntegrationService.EndpointConfig sapConfig = SAPIntegrationService.resolveConfig(
      'FornecedorSAP'
    );

    for (Integradores__c integrador : IntegradorList) {
      String docValue = integrador.CNPJ__c != null
        ? integrador.CNPJ__c
        : integrador.CPF__c;
      String formattedEstado = SAPBusinessPartnerMapper.normalizeState(
        integrador.Estado__c
      );

      IntegradorRequest corpoRequisicao = new IntegradorRequest();
      corpoRequisicao.CardCode = docValue;
      corpoRequisicao.CardName = integrador.RazaoSocial__c;
      corpoRequisicao.CardType = 'cSupplier';
      corpoRequisicao.EmailAddress = integrador.Email__c;
      corpoRequisicao.Phone1 = Utils.removeNonNumericCharacters(
        integrador.Telefone__c
      );
      corpoRequisicao.FederalTaxID = docValue;
      corpoRequisicao.BPAddresses = new List<SAPBusinessPartnerMapper.BPAddress>{};
      corpoRequisicao.BPFiscalTaxIDCollection = new List<SAPBusinessPartnerMapper.BPFiscalTaxID>{};

      // Banking fields — sent independently (each null-checked)
      if (integrador.Conta__c != null) {
        corpoRequisicao.DefaultAccount = integrador.Conta__c;
      }
      if (integrador.Agencia__c != null) {
        corpoRequisicao.DefaultBranch = integrador.Agencia__c;
      }
      if (integrador.Banco__c != null) {
        corpoRequisicao.DefaultBankCode = integrador.Banco__c;
      }

      if (integrador.Logradouro__c != null) {
        corpoRequisicao.BPAddresses.add(
          SAPBusinessPartnerMapper.buildBillingAddress(
            docValue,
            integrador.Logradouro__c,
            'S/N',
            integrador.Bairro__c,
            integrador.CEP__c,
            integrador.Cidade__c,
            integrador.Cidade__c,
            'BR',
            formattedEstado,
            integrador.Complemento__c
          )
        );

        corpoRequisicao.BPAddresses.add(
          SAPBusinessPartnerMapper.buildShippingAddress(
            docValue,
            integrador.Logradouro__c,
            'S/N',
            integrador.Bairro__c,
            integrador.CEP__c,
            integrador.Cidade__c,
            integrador.Cidade__c,
            'BR',
            formattedEstado,
            integrador.Complemento__c
          )
        );
      }

      corpoRequisicao.BPFiscalTaxIDCollection.add(
        SAPBusinessPartnerMapper.buildFiscalTaxId(
          integrador.CPF__c,
          integrador.CNPJ__c,
          docValue
        )
      );

      try {
        HttpResponse response = SAPIntegrationService.post(
          JSON.serialize(corpoRequisicao),
          sapConfig,
          null
        );
        Utils.createLog(
          'IntegracaoSAPIntegrador',
          'sendIntegrador ' + integrador.Id,
          response
        );

        if (response.getBody() != null && response.getBody() != '') {
          Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
          );
          Integer statusCode = Integer.valueOf(responseBody.get('codigoHttp'));
          integrador.SucessoIntegracaoSAP__c = SAPIntegrationService.isSuccess(
            statusCode
          );
          integrador.StatusBodyIntegracaoSAP__c =
            statusCode +
            ' ' +
            response.getBody() +
            ' ' +
            response.getStatus();
        }
      } catch (Exception e) {
        Utils.createLog(
          'IntegracaoSAPIntegrador',
          'sendIntegrador ' + integrador.Id,
          e
        );
        integrador.SucessoIntegracaoSAP__c = false;
        integrador.StatusBodyIntegracaoSAP__c =
          e.getMessage() +
          ' ' +
          e.getStackTraceString();
      }
    }

    IntegradorTriggerHandler.disableTrigger();
    try {
      update IntegradorList;
    } finally {
      IntegradorTriggerHandler.enabled = true;
    }
  }

  public class IntegradorRequest {
    public String CardCode;
    public String CardName;
    public String CardType;
    public String EmailAddress;
    public String Phone1;
    public String FederalTaxID;
    public String DefaultAccount;
    public String DefaultBranch;
    public String DefaultBankCode;
    public SAPBusinessPartnerMapper.BPAddress[] BPAddresses;
    public SAPBusinessPartnerMapper.BPFiscalTaxID[] BPFiscalTaxIDCollection;
  }
}
