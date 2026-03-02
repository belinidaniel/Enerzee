/**
 * @description						 :
 * @author											 : Daniel Belini
 * @group												 :
 * @last modified on	 : 10-17-2025
 * @last modified by	 : Daniel Belini
 **/
public class ProjetoUtils {
  public static Map<String, User> userEmailToUser = new Map<String, User>();
  public static Map<String, Group> developerNameToGroup = new Map<String, Group>();
  public static Map<Id, User> userIdToUser = new Map<Id, User>();

  public static void populateUserEmailMap() {
    if (userEmailToUser.isEmpty()) {
      for (User user : [
        SELECT Id, Email, Name
        FROM User
        WHERE IsActive = TRUE
      ]) {
        userEmailToUser.put(user.Email, user);
      }
    }
  }
  public static user getProjetistaById(ID recordId) {
    List<User> user = [SELECT Id, Email, Name FROM User WHERE Id = :recordId];
    if (!user.isEmpty()) {
      return user[0];
    }
    return null;
  }

  public static user getGestorObrasById(ID recordId) {
    List<User> user = [SELECT Id, Email, Name FROM User WHERE Id = :recordId];
    if (!user.isEmpty()) {
      return user[0];
    }
    return null;
  }

  public static sObject getGroupViabilidadeById(String recordId) {
    List<Group> cGroup = [
      SELECT Id, DeveloperName
      FROM Group
      WHERE DeveloperName = :recordId
    ];
    if (!cGroup.isEmpty()) {
      return cGroup[0];
    }
    return ProjetoUtils.COORDENADOR_DE_VIABILIDADE;
  }

  public static void populateUserIdMap() {
    if (userIdToUser.isEmpty()) {
      for (User user : [
        SELECT Id, Email, Name
        FROM User
      ]) {
        userIdToUser.put(user.Id, user);
      }
    }
  }

  //	 Tipos de Registro
  public static Id RT_BOMBEAMENTO = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
    .get('Bombeamento')
    .getRecordTypeId();
  public static Id RT_ESTACAO_DE_RECARGA = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
    .get('EstacaoRecarga')
    .getRecordTypeId();
  public static Id RT_FINANCIAMENTO = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
    .get('Financiamento')
    .getRecordTypeId();
  public static Id RT_PADRAO_DE_ENTRADA = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
    .get('PadraoEntrada')
    .getRecordTypeId();
  public static Id RT_POSTO_DE_TRANSFORMACAO = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
    .get('PostoTransformacao')
    .getRecordTypeId();
  public static Id RT_SUBESTACAO = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
    .get('Subestacao')
    .getRecordTypeId();
  public static Id RT_UFV_MICRO = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
    .get('UFVMicro')
    .getRecordTypeId();
  public static Id RT_UFV_MINI_ACIMA_DE_300 = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
    .get('UFVacima300')
    .getRecordTypeId();
  public static Id RT_UFV_MINI_ATE_300 = Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
    .get('UFVmini300')
    .getRecordTypeId();

  //	 Status
  public static String STATUS_NAO_DEFINIDO = 'Não definido';
  public static String STATUS_PLANEJAMENTO = 'Planejamento';
  public static String STATUS_PLANEJAMENTO_DE_PROJETO = 'Planejamento de projeto';
  public static String STATUS_PLANEJAMENTO_DE_OBRA = 'Planejamento de Obra';
  public static String STATUS_ELABORACAO_DE_PROJETO = 'Elaboração de projeto';
  public static String STATUS_PROJETO_EM_ANALISE = 'Projeto em análise';
  public static String STATUS_PROJETO_APROVADO = 'Projeto aprovado';
  public static String STATUS_PROJETOS_EM_ELABORACAO = 'Projetos em elaboração';
  public static String STATUS_OBRA_EM_EXECUCAO = 'Obra em execução';
  public static String STATUS_OBRA_CONCLUIDA = 'Obra concluída';
  public static String STATUS_USINA_OPERANDO = 'Usina operando';
  public static String STATUS_OBRA_CONCLUIDA_AGUARDANDO_TROCA_DE_MEDIDOR = 'Obra concluída-Aguardando troca de medidor';
  public static String STATUS_LIGACAO_SOLICITADA = 'Ligação solicitada';
  public static String STATUS_PROJETO_PROTOCOLADO = 'Projeto protocolado';
  public static String STATUS_AGUARDANDO_VISTORIA = 'Aguardando vistoria';

  //	 Usuários chave
  public static User COORDENADOR_DE_ENGENHARIA {
    get {
      populateUserEmailMap();
      return Test.isRunningTest() == true
        ? userEmailToUser.get('daniel.belini@enerzee.com.br')
        : userEmailToUser.get('wellington.santos@enerzee.com.br');
    }
  }

  public static User COORDENADOR_DE_VIABILIDADE {
    get {
      populateUserEmailMap();
      return Test.isRunningTest() == true
        ? userEmailToUser.get('daniel.belini@enerzee.com.br')
        : userEmailToUser.get('wellington.santos@enerzee.com.br');
    }
  }

  public static Map<String, Group> getQueueIdByName() {
    Map<String, Group> queueIdByName = new Map<String, Group>();
    for (Group g : [
      SELECT Id, DeveloperName, Name
      FROM Group
    ]) {
      addKeyToQueueMap(queueIdByName, normalizeKey(g.DeveloperName), g);
      addKeyToQueueMap(queueIdByName, normalizeKey(g.Name), g);
    }
    return queueIdByName;
  }

  private static String normalizeKey(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    return value.trim().replace(' ', '_').toUpperCase();
  }

  private static void addKeyToQueueMap(
    Map<String, Group> target,
    String key,
    Group g
  ) {
    if (!String.isBlank(key) && target != null && g != null) {
      target.put(key, g);
    }
  }

  public static boolean hasEngineerCoordinatorSetProjectResponsibles(
    Projeto__c newProject,
    Projeto__c oldProject
  ) {
    return hasEngineerCoordinatorSetManager(newProject, oldProject) &&
      hasEngineerCoordinatorSetDevisor(newProject, oldProject);
  }

  public static boolean hasEngineerCoordinatorSetManager(
    Projeto__c newProject,
    Projeto__c oldProject
  ) {
    return (newProject.GestorObra__c != null &&
    oldProject.GestorObra__c == null);
  }

  public static boolean hasEngineerCoordinatorSetDevisor(
    Projeto__c newProject,
    Projeto__c oldProject
  ) {
    return (newProject.Projetista__c != null &&
    oldProject.Projetista__c == null);
  }

  public static Id getRecordTypeIdByDeveloperName(String developerName) {
    return Schema.SObjectType.Projeto__c.getRecordTypeInfosByDeveloperName()
      .get(developerName)
      .getRecordTypeId();
  }

  public static Id getRecordTypeIdByName(String name) {
    return Schema.SObjectType.Projeto__c.getRecordTypeInfosByName()
      .get(name)
      .getRecordTypeId();
  }

  public static boolean isStatusChanging(
    Projeto__c newProject,
    Projeto__c oldProject
  ) {
    return newProject.Status__c != oldProject.Status__c;
  }
}
