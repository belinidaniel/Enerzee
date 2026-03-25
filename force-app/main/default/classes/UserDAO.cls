/**
 * @description       : DAO para queries sobre User e Group (Queue).
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-25-2026
 * @last modified by  : Daniel Belini
 * @test              : AdditionalCoverageNewClassesTest, InstalacaoBOTest, OpportunityBOAdditionalTest,
 *                       OpportunityBOCoverageTest, OpportunityBOEmailTest, OpportunityBOHighCoverageTest,
 *                       OpportunityBOIntegrationVOFixesTest, OpportunityBOPaymentConfirmationTaskTest,
 *                       OpportunityBOPaymentReminderTaskTest, OpportunityDisqualifyLeadsTest, OpportunityTriggerTest,
 *                       PDFControllerExtensionExtraTest
 **/
public with sharing class UserDAO {
  private static final String INTEGRATION_USER_USERNAME = 'integracao@lab065.com';

  /** Retorna o Id do usuário de integração Nivello/VO, ou null se inativo/inexistente. */
  public static Id findIntegrationUserId() {
    List<User> users = [
      SELECT Id
      FROM User
      WHERE Username = :INTEGRATION_USER_USERNAME AND IsActive = TRUE
      LIMIT 1
    ];
    return users.isEmpty() ? null : users[0].Id;
  }

  /** Retorna o Id do primeiro usuário ativo cujo Email corresponde ao padrão LIKE fornecido. */
  public static Id findActiveUserIdByEmailLike(String emailLike) {
    if (String.isBlank(emailLike)) {
      return null;
    }
    List<User> users = [
      SELECT Id
      FROM User
      WHERE Email LIKE :emailLike AND IsActive = TRUE
      LIMIT 1
    ];
    return users.isEmpty() ? null : users[0].Id;
  }

  /** Retorna Map<userId, IsActive> para os Ids fornecidos. */
  public static Map<Id, Boolean> findActiveStatusByUserIds(Set<Id> userIds) {
    Map<Id, Boolean> result = new Map<Id, Boolean>();
    if (userIds.isEmpty()) {
      return result;
    }
    for (User u : [SELECT Id, IsActive FROM User WHERE Id IN :userIds]) {
      result.put(u.Id, u.IsActive);
    }
    return result;
  }

  /** Retorna o Id da fila (Group) pelo DeveloperName, ou null se não encontrada. */
  public static Id findQueueIdByDeveloperName(String developerName) {
    if (String.isBlank(developerName)) {
      return null;
    }
    List<Group> queues = [
      SELECT Id
      FROM Group
      WHERE Type = 'Queue' AND DeveloperName = :developerName
      LIMIT 1
    ];
    return queues.isEmpty() ? null : queues[0].Id;
  }
}
