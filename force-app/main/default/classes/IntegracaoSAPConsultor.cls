/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-18-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoSAPConsultorTest
 **/
public without sharing class IntegracaoSAPConsultor implements Queueable, Database.AllowsCallouts {
  private final Set<Id> recordIds;

  public IntegracaoSAPConsultor(Set<Id> recordIds) {
    this.recordIds = recordIds;
  }

  public void execute(QueueableContext ctx) {
    List<Consultor__c> consultorList = [
      SELECT
        Id,
        IdVirtualOffice__c,
        CPF__c,
        CNPJ__c,
        SeCPFouCNPJ__c,
        Name,
        Email__c,
        Telefone__c,
        RuaCobranca__c,
        CodigoPostalCobranca__c,
        CidadeCobranca__c,
        EstadoCobranca__c,
        BairroCobranca__c,
        MunicipioCobranca__c,
        ComplementoCobranca__c,
        NumeroRuaCobranca__c,
        RuaEntrega__c,
        CodigoPostalEntrega__c,
        CidadeEntrega__c,
        EstadoEntrega__c,
        BairroEntrega__c,
        MunicipioEntrega__c,
        ComplementoEntrega__c,
        NumeroRuaEntrega__c,
        SucessoIntegracaoSAP__c,
        StatusBodyIntegracaoSAP__c
      FROM Consultor__c
      WHERE Id IN :recordIds
    ];

    SAPIntegrationService.EndpointConfig sapConfig = SAPIntegrationService.resolveConfig(
      'ClienteSAP'
    );

    for (Consultor__c acc : consultorList) {
      String docValue = acc.SeCPFouCNPJ__c;
      ConsultorRequest corpoRequisicao = new ConsultorRequest();
      corpoRequisicao.CardCode = docValue;
      corpoRequisicao.CardName = acc.Name;
      corpoRequisicao.CardType = 'cCustomer';
      corpoRequisicao.EmailAddress = acc.Email__c;
      corpoRequisicao.Phone1 = Utils.removeNonNumericCharacters(
        acc.Telefone__c
      );
      corpoRequisicao.FederalTaxID = docValue;
      corpoRequisicao.BPAddresses = new List<SAPBusinessPartnerMapper.BPAddress>{};
      corpoRequisicao.BPFiscalTaxIDCollection = new List<SAPBusinessPartnerMapper.BPFiscalTaxID>{};

      if (acc.RuaCobranca__c != null) {
        corpoRequisicao.BPAddresses.add(
          SAPBusinessPartnerMapper.buildBillingAddress(
            docValue,
            acc.RuaCobranca__c,
            acc.NumeroRuaCobranca__c,
            acc.BairroCobranca__c,
            acc.CodigoPostalCobranca__c,
            acc.CidadeCobranca__c,
            acc.MunicipioCobranca__c,
            'BR',
            SAPBusinessPartnerMapper.normalizeState(acc.EstadoCobranca__c),
            acc.ComplementoCobranca__c
          )
        );
      }

      if (acc.RuaEntrega__c != null) {
        corpoRequisicao.BPAddresses.add(
          SAPBusinessPartnerMapper.buildShippingAddress(
            docValue,
            acc.RuaEntrega__c,
            acc.NumeroRuaEntrega__c,
            acc.BairroEntrega__c,
            acc.CodigoPostalEntrega__c,
            acc.CidadeEntrega__c,
            acc.MunicipioEntrega__c,
            'BR',
            SAPBusinessPartnerMapper.normalizeState(acc.EstadoEntrega__c),
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
          'IntegracaoSAPConsultor request body: ' + requestBody
        );
        HttpResponse response = SAPIntegrationService.post(
          requestBody,
          sapConfig,
          null
        );
        Utils.createLog(
          'IntegracaoSAPConsultor',
          'sendConsultor ' + acc.Id,
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
        Utils.createLog('IntegracaoSAPConsultor', 'sendConsultor ' + acc.Id, e);
        acc.SucessoIntegracaoSAP__c = false;
        acc.StatusBodyIntegracaoSAP__c =
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

  public class ConsultorRequest {
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
