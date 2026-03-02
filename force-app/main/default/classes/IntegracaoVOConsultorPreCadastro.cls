public with sharing class IntegracaoVOConsultorPreCadastro {
  @future(callout=true)
  public static void sendConsultor(Set<Id> triggerIds) {
    List<Lead> leadList = [
      SELECT
        Id,
        FirstName,
        LastName,
        Email,
        DataNascimento__c,
        CPFCNPJ__c,
        Street,
        StreetNumber__c,
        PostalCode,
        Complemento__c,
        ConsultorRegional__r.Login_no_virtual__c,
        ConsultorRegional__r.IdVirtualOffice2__c
      FROM Lead
      WHERE Id IN :triggerIds
    ];

    for (Lead lead : leadList) {
      ConsultorRequest corpoRequisicao = new ConsultorRequest();
      corpoRequisicao.IdLeadSalesForce = lead.Id;
      corpoRequisicao.NomeCompleto = lead.FirstName + ' ' + lead.LastName;
      corpoRequisicao.email = lead.Email;
      corpoRequisicao.DataNascimento = lead.DataNascimento__c == null
        ? '2000-01-01'
        : String.valueOf(lead.DataNascimento__c);
      corpoRequisicao.Documento = lead.CPFCNPJ__c;
      corpoRequisicao.LoginUsuarioPai = lead.ConsultorRegional__r.Login_no_virtual__c;
      corpoRequisicao.IdUsuarioPai = lead.ConsultorRegional__r != null
        ? Integer.valueOf(lead.ConsultorRegional__r.IdVirtualOffice2__c)
        : null;

      BPAddress bpAddress = new BPAddress();
      bpAddress.Rua = lead.street;
      bpAddress.Numero = lead.streetNumber__c;
      bpAddress.Cep = lead.postalCode;
      bpAddress.Complemento = lead.complemento__c;

      corpoRequisicao.Endereco = bpAddress;

      try {
        HttpResponse response = chamadaIntegracao(
          JSON.serialize(corpoRequisicao),
          'ConsultorVO'
        );
        Utils.createLog(
          'IntegracaoVOConsultorPreCadastro',
          'sendConsultor ' + lead.Id,
          response
        );

        if (response.getBody() != null && response.getBody() != '') {
          Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
          );
          Boolean success = Boolean.valueOf(responseBody.get('erro'));

          if (!success) {
            String IdVirtualOffice = String.valueOf(
              responseBody.get('idusuario')
            );
            lead.IdVirtualOffice__c = IdVirtualOffice;
          } else {
            String ErrorIntegracaoVO = String.valueOf(
              responseBody.get('retorno')
            );
            lead.ErrorIntegracaoVO__c = ErrorIntegracaoVO != null
              ? ErrorIntegracaoVO
              : 'Erro desconhecido na integração com Virtual Office';
          }

          lead.SucessoIntegracaoVO__c = !success;
          lead.StatusBodyIntegracaoVO__c =
            response.getStatusCode() +
            ' ' +
            response.getBody() +
            ' ' +
            response.getStatus();
        }
      } catch (Exception e) {
        Utils.createLog(
          'IntegracaoVOConsultorPreCadastro',
          'sendConsultor ' + lead.Id,
          e
        );

        lead.SucessoIntegracaoVO__c = false;
        lead.ErrorIntegracaoVO__c = 'Erro desconhecido na integração com Virtual Office';
        lead.StatusBodyIntegracaoVO__c =
          e.getMessage() +
          ' ' +
          e.getStackTraceString();
      }
    }

    LeadTriggerHandler.disableTrigger();
    update leadList;
    LeadTriggerHandler.enableTrigger();
  }

  private static HttpResponse chamadaIntegracao(
    String body,
    String endpointName
  ) {
    Integrador__mdt parametrosIntegracao = [
      SELECT Id, URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = :endpointName
      LIMIT 1
    ];

    if (parametrosIntegracao == null) {
      throw new IllegalArgumentException(
        'Endpoint não encontrado para: ' + endpointName
      );
    }

    Http httpObj = new Http();
    HttpRequest request = new HttpRequest();

    request.setEndpoint(parametrosIntegracao.URL__c);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setBody(body);

    return Utils.callIntegrationVO(request);
  }

  public class ConsultorRequest {
    public Id IdLeadSalesForce;
    public String NomeCompleto;
    public String email;
    public String DataNascimento;
    public String Documento;
    public String LoginUsuarioPai;
    public Integer IdUsuarioPai;
    public BPAddress Endereco;
  }

  public class BPAddress {
    public String Rua;
    public String Numero;
    public String Cep;
    public String Complemento;
  }
}
