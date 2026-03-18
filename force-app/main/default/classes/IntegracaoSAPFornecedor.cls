/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-18-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoSAPCoverageTest
 **/
public without sharing class IntegracaoSAPFornecedor implements Queueable, Database.AllowsCallouts {
  private final Set<Id> recordIds;

  public IntegracaoSAPFornecedor(Set<Id> recordIds) {
    this.recordIds = recordIds;
  }

  public void execute(QueueableContext ctx) {
    List<Consultor__c> consultorList = [
      SELECT
        Id,
        CPF__c,
        CNPJ__c,
        SeCPFouCNPJ__c,
        Name,
        Email__c,
        Telefone__c,
        RuaCobranca__c,
        BairroCobranca__c,
        CodigoPostalCobranca__c,
        CidadeCobranca__c,
        MunicipioCobranca__c,
        PaisCobranca__c,
        EstadoCobranca__c,
        ComplementoCobranca__c,
        NumeroRuaCobranca__c,
        RuaEntrega__c,
        BairroEntrega__c,
        CodigoPostalEntrega__c,
        CidadeEntrega__c,
        MunicipioEntrega__c,
        PaisEntrega__c,
        EstadoEntrega__c,
        ComplementoEntrega__c,
        NumeroRuaEntrega__c,
        SucessoIntegracaoSAP__c,
        StatusBodyIntegracaoSAP__c,
        Banco__c,
        Conta__c,
        Agencia__c
      FROM Consultor__c
      WHERE Id IN :recordIds
    ];

    SAPIntegrationService.EndpointConfig sapConfig = SAPIntegrationService.resolveConfig(
      'FornecedorSAP'
    );

    for (Consultor__c consultor : consultorList) {
      FornecedorRequest corpoRequisicao = new FornecedorRequest();
      corpoRequisicao.CardCode = consultor.SeCPFouCNPJ__c;
      corpoRequisicao.CardName = consultor.Name;
      corpoRequisicao.CardType = 'cSupplier';
      corpoRequisicao.EmailAddress = consultor.Email__c;
      corpoRequisicao.Phone1 = consultor.Telefone__c;
      corpoRequisicao.FederalTaxID = consultor.SeCPFouCNPJ__c;

      // Banking fields — sent independently (SAL-314 fix)
      if (consultor.Conta__c != null) {
        corpoRequisicao.DefaultAccount = consultor.Conta__c;
      }
      if (consultor.Agencia__c != null) {
        corpoRequisicao.DefaultBranch = consultor.Agencia__c;
      }
      if (consultor.Banco__c != null) {
        corpoRequisicao.DefaultBankCode = consultor.Banco__c;
      }

      corpoRequisicao.BPAddresses = new List<SAPBusinessPartnerMapper.BPAddress>{};
      corpoRequisicao.BPFiscalTaxIDCollection = new List<SAPBusinessPartnerMapper.BPFiscalTaxID>{};

      corpoRequisicao.BPAddresses.add(
        SAPBusinessPartnerMapper.buildBillingAddress(
          consultor.SeCPFouCNPJ__c,
          consultor.RuaCobranca__c,
          consultor.NumeroRuaCobranca__c,
          consultor.BairroCobranca__c,
          consultor.CodigoPostalCobranca__c,
          consultor.CidadeCobranca__c,
          consultor.MunicipioCobranca__c,
          SAPBusinessPartnerMapper.normalizeCountry(consultor.PaisCobranca__c),
          consultor.EstadoCobranca__c,
          consultor.ComplementoCobranca__c
        )
      );

      corpoRequisicao.BPAddresses.add(
        SAPBusinessPartnerMapper.buildShippingAddress(
          consultor.SeCPFouCNPJ__c,
          consultor.RuaEntrega__c,
          consultor.NumeroRuaEntrega__c,
          consultor.BairroEntrega__c,
          consultor.CodigoPostalEntrega__c,
          consultor.CidadeEntrega__c,
          consultor.MunicipioEntrega__c,
          SAPBusinessPartnerMapper.normalizeCountry(consultor.PaisEntrega__c),
          consultor.EstadoEntrega__c,
          consultor.ComplementoEntrega__c
        )
      );

      corpoRequisicao.BPFiscalTaxIDCollection.add(
        SAPBusinessPartnerMapper.buildFiscalTaxId(
          consultor.CPF__c,
          consultor.CNPJ__c,
          consultor.SeCPFouCNPJ__c
        )
      );

      try {
        HttpResponse response = SAPIntegrationService.post(
          JSON.serialize(corpoRequisicao),
          sapConfig,
          null
        );
        Utils.createLog(
          'IntegracaoSAPFornecedor',
          'sendFornecedor ' + consultor.Id,
          response
        );

        if (response.getBody() != null && response.getBody() != '') {
          Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
          );
          Integer statusCode = Integer.valueOf(responseBody.get('codigoHttp'));
          consultor.SucessoIntegracaoSAP__c = SAPIntegrationService.isSuccess(
            statusCode
          );
          consultor.StatusBodyIntegracaoSAP__c =
            statusCode +
            ' ' +
            response.getBody() +
            ' ' +
            response.getStatus();
        }
      } catch (Exception e) {
        Utils.createLog(
          'IntegracaoSAPFornecedor',
          'sendFornecedor ' + consultor.Id,
          e
        );
        consultor.SucessoIntegracaoSAP__c = false;
        consultor.StatusBodyIntegracaoSAP__c =
          e.getMessage() +
          ' ' +
          e.getStackTraceString();
      }
    }

    ConsultorTriggerHandler.disableTrigger();
    try {
      update consultorList;
    } finally {
      ConsultorTriggerHandler.enableTrigger();
    }
  }

  public class FornecedorRequest {
    public String CardCode;
    public String CardName;
    public String CardType;
    public String EmailAddress;
    public String DefaultAccount;
    public String DefaultBranch;
    public String DefaultBankCode;
    public String Phone1;
    public String FederalTaxID;
    public SAPBusinessPartnerMapper.BPAddress[] BPAddresses;
    public SAPBusinessPartnerMapper.BPFiscalTaxID[] BPFiscalTaxIDCollection;
  }
}
