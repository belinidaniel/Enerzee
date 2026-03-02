@IsTest
private class ProjetoUtilsTest {
  @IsTest
  static void shouldLoadQueuesAndUsers() {
    Group g = new Group(
      Name = 'FilaTeste',
      DeveloperName = 'FilaTeste',
      Type = 'Queue'
    );
    insert g;

    Map<String, Group> queueMap = ProjetoUtils.getQueueIdByName();
    System.assert(queueMap.size() > 0);

    User u = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
    System.assertNotEquals(null, ProjetoUtils.getProjetistaById(u.Id));
    System.assertNotEquals(null, ProjetoUtils.getGestorObrasById(u.Id));

    SObject groupFound = ProjetoUtils.getGroupViabilidadeById('FilaTeste');
    System.assertNotEquals(null, groupFound);
  }
}
