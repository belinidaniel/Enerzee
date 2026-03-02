/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 11-24-2025
 * @last modified by	 : Daniel Belini
 **/
public without sharing class Utils {
  public class LogDTO {
    public String className;
    public String methodName;
    public String httpMethod;
    public String requestBody;
    public String requestURI;
    public String responseBody;
    public Integer statusCode;
    public String status;
    public String message;
    public String typeName;
    public String stackTraceString;
    public String lineNumber;
    public String relatedId;
  }

  //Creates error logs
  public static Log__c createLogNoInsert(
    String className,
    String methodName,
    Object source
  ) {
    return createLogNoInsert(className, methodName, source, null);
  }

  public static Log__c createLogNoInsert(
    String className,
    String methodName,
    Object source,
    String relatedId
  ) {
    Log__c lg = new Log__c(
      Class__c = className,
      Method__c = methodName,
      RelatedId__c = relatedId
    );

    //Set additional log fields based on source type
    //General exceptions
    if (source instanceof Exception) {
      Exception e = (Exception) source;

      lg.Message__c = e.getMessage();
      lg.Type__c = e.getTypeName();
      lg.LineNumber__c = String.valueOf(e.getLineNumber());
      lg.StackTraceString__c = e.getStackTraceString();
    }
    //Callouts
    else if (source instanceof HttpResponse) {
      HttpResponse resp = (HttpResponse) source;

      lg.StatusCode__c = resp.getStatusCode();
      lg.ResponseBody__c = trimToBodyLimit(resp.getBody());
      lg.Status__c = resp.getStatus();
    } else if (source instanceof HttpRequest) {
      HttpRequest req = (HttpRequest) source;

      lg.RequestBody__c = trimToBodyLimit(req.getBody());
      lg.HTTPMethod__c = req.getMethod();
      lg.RequestURI__c = req.getEndpoint();
    }
    //Custom Apex REST
    else if (source instanceof System.RestRequest) {
      RestRequest req = (RestRequest) source;

      lg.RequestBody__c = trimToBodyLimit(req.requestBody.toString());
      lg.HTTPMethod__c = req.httpMethod;
      lg.RequestURI__c = req.requestURI;
    }

    return lg;
  }

  public static Log__c createLogNoInsert(LogDTO dto) {
    if (dto == null) {
      return null;
    }

    Log__c lg = new Log__c(
      Class__c = dto.className,
      Method__c = dto.methodName,
      RelatedId__c = dto.relatedId
    );

    lg.HTTPMethod__c = dto.httpMethod;
    lg.RequestBody__c = trimToBodyLimit(dto.requestBody);
    lg.RequestURI__c = dto.requestURI;
    lg.ResponseBody__c = trimToBodyLimit(dto.responseBody);
    lg.StatusCode__c = dto.statusCode;
    lg.Status__c = dto.status;
    lg.Message__c = dto.message;
    lg.Type__c = dto.typeName;
    lg.StackTraceString__c = dto.stackTraceString;
    lg.LineNumber__c = dto.lineNumber;

    return lg;
  }

  public static void createLog(
    String className,
    String methodName,
    Object source
  ) {
    insert createLogNoInsert(className, methodName, source, null);
  }

  public static void createLog(
    String className,
    String methodName,
    Object source,
    String relatedId
  ) {
    insert createLogNoInsert(className, methodName, source, relatedId);
  }

  public static void createLog(LogDTO dto) {
    Log__c log = createLogNoInsert(dto);
    if (log != null) {
      insert log;
    }
  }

  public static void createLogFromJson(String logJSON) {
    if (String.isBlank(logJSON)) {
      return;
    }
    LogDTO dto = (LogDTO) JSON.deserialize(logJSON, LogDTO.class);
    createLog(dto);
  }

  private static String trimToBodyLimit(String content) {
    if (String.isEmpty(content)) {
      return content;
    }
    return content.length() > 131072 ? content.substring(0, 131072) : content;
  }

  /* Método que recebe um request e devolve response tentando		 o token de acesso da Nivello, se existir */
  public static HttpResponse callIntegrationNivello(HttpRequest request) {
    Http http = new Http();
    HttpResponse response = new HttpResponse();
    Boolean pegarNovoToken = false;

    //Se existir parâmetro previamente salvo, tenta utilizar
    //primeiramente verificando na própria classe de serviços

    if (
      TokenAPINivelloWs.access_token != null &&
      TokenAPINivelloWs.access_token != ''
    ) {
      request.setHeader('Bearer', TokenAPINivelloWs.access_token);
    }
    //depois verifica nos parâmetros
    else {
      Integrador__mdt token = [
        SELECT Id, URL__c, login__c, senha__c, LastToken__c, validade_token__c
        FROM Integrador__mdt
        WHERE DeveloperName = 'Login_Nivello'
      ];

      if (token.LastToken__c != null && token.LastToken__c != '') {
        request.setHeader('Bearer', token.LastToken__c);
      }
      //se não achar, precisa de um novo token
      else {
        pegarNovoToken = true;
      }
    }

    TokenAPINivelloWs sts = new TokenAPINivelloWs();
    Boolean sucesso = false;

    //caso já tenha algum token, tenta fazer a chamada
    if (!pegarNovoToken) {
      response = http.send(request);

      //erro de autorização, precisa pegar novo token
      if (response.getStatusCode() == 401) {
        pegarNovoToken = true;

        TokenAPINivelloWs.access_token = '';
        sucesso = sts.callService();
      }

      //se precisar pegar token, faz a chamada do serviço
    } else if (!Test.isRunningTest()) {
      //limpando a variável, caso esteja setada
      TokenAPINivelloWs.access_token = '';
      sucesso = sts.callService();
    }

    System.debug(response);

    //se sucesso ao pegar	 o token, chama o serviço original requisitado
    //não trata novamente o erro de autorização. só é feita uma tentativa.
    if (sucesso || Test.isRunningTest()) {
      if (!Test.isRunningTest()) {
        System.debug('token ->' + sts.tokenResponse.data.token);
        request.setHeader(
          'Authorization',
          'Bearer ' + sts.tokenResponse.data.token
        );
      }

      request.setTimeout(120000);

      response = http.send(request);
    }
    //se der algum erro, retorna a resposta para que a classe que chamou faça a tratativa necessária
    else {
      response = sts.finalResponse;
    }

    System.debug(response);

    // Utils.createLog('Utils', 'callIntegrationNivello - request', request);
    // Utils.createLog('Utils', 'callIntegrationNivello - response', response);

    return response;
  }

  public static HttpResponse callIntegrationVO(HttpRequest request) {
    Http http = new Http();
    HttpResponse response = new HttpResponse();

    Boolean NovoToken = false;
    Boolean Sucesso = false;

    if (TokenAPIVOWs.access_token != null && TokenAPIVOWs.access_token != '') {
      request.setHeader('Bearer', TokenAPIVOWs.access_token);
    } else {
      Integrador__mdt token = [
        SELECT Id, URL__c, login__c, senha__c, LastToken__c, validade_token__c
        FROM Integrador__mdt
        WHERE DeveloperName = 'Login_VO'
      ];

      if (token.LastToken__c != null && token.LastToken__c != '') {
        request.setHeader('Bearer', token.LastToken__c);
      } else {
        NovoToken = true;
      }
    }

    TokenAPIVOWs Status = new TokenAPIVOWs();

    if (!NovoToken) {
      response = http.send(request);

      if (response.getStatusCode() == 401) {
        TokenAPIVOWs.access_token = '';
        Sucesso = Status.callService();
      }
    } else if (!Test.isRunningTest()) {
      TokenAPIVOWs.access_token = '';
      Sucesso = Status.callService();
    }

    if (Sucesso || Test.isRunningTest()) {
      if (!Test.isRunningTest()) {
        request.setHeader(
          'Authorization',
          'Bearer ' + Status.tokenResponse.access_token
        );
      }

      request.setTimeout(120000);
      response = http.send(request);
    } else {
      response = Status.finalResponse;
    }

    // Logging via DML aqui pode conflitar com múltiplos callouts sequenciais.
    // Mantemos apenas debug para evitar "uncommitted work pending".
    // System.debug('callIntegrationVO response status: ' + (response != null ? response.getStatusCode() : 'null'));

    return response;
  }

  public static HttpResponse callIntegrationSAP(HttpRequest request) {
    Http http = new Http();
    HttpResponse response = new HttpResponse();
    request.setTimeout(120000);

    response = http.send(request);

    Utils.createLog('Utils', 'callIntegrationSAP - request', request);
    Utils.createLog('Utils', 'callIntegrationSAP - response', response);

    return response;
  }

  // public static void saveLastToken(String token)
  // {
  //				 String hour = String.valueOf(Datetime.now().hour());
  //				 String min = String.valueOf(Datetime.now().minute()+5);
  //				 String ss = String.valueOf(Datetime.now().second());

  //				 //parse to cron expression
  //				 String nextFireTime = ss + ' ' + min + ' ' + hour + ' * * ?';

  //				 //ScheduleSaveToken s = new ScheduleSaveToken(token);
  //				 //String jobID = system.schedule('Save Token', nextFireTime, s);
  // }

  public static void notificacaoPersonalizada(
    String msg,
    String titulo,
    String usrid,
    String alvo
  ) {
    Id typeId = [
      SELECT Id
      FROM CustomNotificationType
      WHERE masterLabel = 'Padrão'
      LIMIT 1
    ]
    .Id;

    Messaging.CustomNotification notification = new Messaging.CustomNotification();

    notification.setBody(msg);
    notification.setTitle(titulo);
    notification.setSenderId(usrid);
    notification.setNotificationTypeId(typeId);
    notification.setTargetId(alvo);

    notification.send(new Set<String>{ usrid });
  }

  public static String removeNonNumericCharacters(String input) {
    if (String.isNotBlank(input)) {
      return input.replaceAll('[^0-9]', ''); // Remove qualquer caractere que não seja numérico
    }
    return null; // Retorna null se a entrada for nula ou vazia
  }
}
