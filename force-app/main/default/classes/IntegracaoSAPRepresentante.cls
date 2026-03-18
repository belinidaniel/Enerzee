/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-18-2026
 * @last modified by  : Daniel Belini
 * @test              : IntegracaoSAPTest
 **/
public without sharing class IntegracaoSAPRepresentante implements Queueable, Database.AllowsCallouts {
  private final Set<Id> recordIds;

  public IntegracaoSAPRepresentante(Set<Id> recordIds) {
    this.recordIds = recordIds;
  }

  public void execute(QueueableContext ctx) {
    List<Consultor__c> consultorList = [
      SELECT
        Id,
        Name,
        Observacoes__c,
        Comissao__c,
        Ativo__c,
        Telefone__c,
        Celular__c,
        Fax__c,
        Email__c,
        SeCPFOuCNPJ__c
      FROM Consultor__c
      WHERE Id IN :recordIds
    ];

    SAPIntegrationService.EndpointConfig sapConfig = SAPIntegrationService.resolveConfig(
      'RepresentanteSAP'
    );

    for (Consultor__c consultor : consultorList) {
      RepresentanteRequest corpoRequisicao = new RepresentanteRequest();
      corpoRequisicao.U_Alfa_IdIntegracao = consultor.SeCPFOuCNPJ__c;
      corpoRequisicao.SalesEmployeeName = consultor.Name;
      corpoRequisicao.Remarks = consultor.Observacoes__c;
      corpoRequisicao.CommissionForSalesEmployee = consultor.Comissao__c;
      corpoRequisicao.CommissionGroup = null;
      corpoRequisicao.Active = consultor.Ativo__c ? 'tYES' : 'tNO';
      corpoRequisicao.Telephone = consultor.Telefone__c;
      corpoRequisicao.Mobile = consultor.Celular__c;
      corpoRequisicao.Fax = consultor.Fax__c;
      corpoRequisicao.Email = consultor.Email__c;

      try {
        HttpResponse response = SAPIntegrationService.post(
          JSON.serialize(corpoRequisicao),
          sapConfig,
          null
        );
        Utils.createLog(
          'IntegracaoSAPRepresentante',
          'sendRepresentante ' + consultor.Id,
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
          'IntegracaoSAPRepresentante',
          'sendRepresentante ' + consultor.Id,
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

  public class RepresentanteRequest {
    public String U_Alfa_IdIntegracao;
    public String SalesEmployeeName;
    public String Remarks;
    public Double CommissionForSalesEmployee;
    public Integer CommissionGroup;
    public String Active;
    public String Telephone;
    public String Mobile;
    public String Fax;
    public String Email;
  }
}
