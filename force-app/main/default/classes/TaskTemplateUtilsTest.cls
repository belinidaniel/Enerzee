/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class TaskTemplateUtilsTest {
  @IsTest
  static void shouldCombineDateAndTime() {
    Date d = Date.newInstance(2025, 1, 1);
    DateTime result = TaskTemplateUtils.combineDateAndTime(
      d,
      Time.newInstance(10, 30, 0, 0)
    );
    System.assertEquals(DateTime.newInstance(2025, 1, 1, 10, 30, 0), result);
  }

  @IsTest
  static void shouldParseIntegerWithFallback() {
    System.assertEquals(5, TaskTemplateUtils.parseInteger('5', 1));
    System.assertEquals(1, TaskTemplateUtils.parseInteger('abc', 1));
  }

  @IsTest
  static void shouldCalculateDueDateFromPrazoDiasUteis() {
    Date base = Date.newInstance(2025, 6, 2);
    Date result = TaskTemplateUtils.calculateDueDate(base, '3', null);
    Assert.isNotNull(result, 'Due date nao deve ser nulo.');
  }

  @IsTest
  static void shouldCalculateDueDateFromDataVencimentoDMais() {
    Date base = Date.newInstance(2025, 6, 2);
    Date result = TaskTemplateUtils.calculateDueDate(base, null, '5');
    Assert.isNotNull(result, 'Due date calculado por D+5 nao deve ser nulo.');
  }

  @IsTest
  static void shouldCalculateDueDateWithBothNull() {
    Date base = Date.newInstance(2025, 6, 2);
    Date result = TaskTemplateUtils.calculateDueDate(base, null, null);
    Assert.areEqual(base, result, 'Com workingDays=0 deve retornar a data base.');
  }

  @IsTest
  static void shouldCalculateDueDateWithNullStartDate() {
    Date result = TaskTemplateUtils.calculateDueDate(null, '2', null);
    Assert.isNotNull(result, 'Deve usar today quando startDate for nulo.');
  }

  @IsTest
  static void shouldReturnDefaultDueTime() {
    Time t = TaskTemplateUtils.defaultDueTime();
    Assert.areEqual(17, t.hour(), 'Hora padrao deve ser 17h.');
    Assert.areEqual(0, t.minute());
  }

  @IsTest
  static void shouldReturnNullWhenActivityDateIsNull() {
    DateTime result = TaskTemplateUtils.combineDateAndTime(null, Time.newInstance(10, 0, 0, 0));
    Assert.isNull(result, 'Deve retornar null quando activityDate for nulo.');
  }

  @IsTest
  static void shouldCombineDateWithDateTimeInput() {
    Date d = Date.newInstance(2025, 3, 15);
    DateTime dtInput = DateTime.newInstance(2025, 1, 1, 9, 30, 0);
    DateTime result = TaskTemplateUtils.combineDateAndTime(d, dtInput);
    Assert.areEqual(9, result.hour(), 'Hora deve vir do DateTime passado.');
    Assert.areEqual(30, result.minute());
  }

  @IsTest
  static void shouldFallbackToDefaultTimeForNonTimeInput() {
    Date d = Date.newInstance(2025, 3, 15);
    DateTime result = TaskTemplateUtils.combineDateAndTime(d, 'not a time value');
    Assert.areEqual(17, result.hour(), 'Deve usar hora padrao 17h como fallback.');
  }

  @IsTest
  static void shouldResolveOwnerReturnsNullForNullLine() {
    Id result = TaskTemplateUtils.resolveOwner(null, null, null, null);
    Assert.isNull(result, 'Deve retornar null quando line for nulo e nao ha mapa.');
  }

  @IsTest
  static void shouldResolveOwnerWithQueueType() {
    Group testQueue = new Group(Name = 'TTUtils Queue', Type = 'Queue');
    insert testQueue;

    ProjetoBO.TaskProjectTableLine line = new ProjetoBO.TaskProjectTableLine();
    line.TipoDeProprietario = 'QUEUE';
    line.Responsavel = 'TTUtils Queue';

    Map<String, Group> queueMap = new Map<String, Group>{ 'TTUTILS_QUEUE' => testQueue };

    Id result = TaskTemplateUtils.resolveOwner(line, null, queueMap, null);
    Assert.areEqual(testQueue.Id, result, 'Deve retornar o Id da fila.');
  }

  @IsTest
  static void shouldResolveOwnerWithRoleTypeNoMatchReturnsNull() {
    ProjetoBO.TaskProjectTableLine line = new ProjetoBO.TaskProjectTableLine();
    line.TipoDeProprietario = 'ROLE';
    line.Responsavel = 'RoleNaoExistente_XYZ';

    Id result = TaskTemplateUtils.resolveOwner(line, new Map<String, User>(), null, null);
    Assert.isNull(result, 'Deve retornar null quando role nao encontrada.');
  }

  @IsTest
  static void shouldResolveOwnerWithRoleTypeFromMap() {
    User u = [SELECT Id, Name, IsActive FROM User WHERE IsActive = TRUE LIMIT 1];

    ProjetoBO.TaskProjectTableLine line = new ProjetoBO.TaskProjectTableLine();
    line.TipoDeProprietario = 'ROLE';
    line.Responsavel = u.Name;

    Map<String, User> roleToUser = new Map<String, User>{ u.Name => u };

    Id result = TaskTemplateUtils.resolveOwner(line, roleToUser, null, null);
    Assert.areEqual(u.Id, result, 'Deve retornar userId do mapa de roles.');
  }

  @IsTest
  static void shouldResolveOwnerWithUsuarioOwner() {
    Account acc = new Account(Name = 'TTUtils Acc Owner');
    insert acc;
    acc = [SELECT Id, OwnerId FROM Account WHERE Id = :acc.Id];

    ProjetoBO.TaskProjectTableLine line = new ProjetoBO.TaskProjectTableLine();
    line.TipoDeProprietario = 'USUARIO';
    line.Responsavel = 'OWNER';

    Id result = TaskTemplateUtils.resolveOwner(line, null, null, acc);
    Assert.isNotNull(result, 'Deve retornar OwnerId do registro pai.');
  }

  @IsTest
  static void shouldResolveOwnerWithUsuarioEmailFallback() {
    User u = [SELECT Id, Email, IsActive FROM User WHERE IsActive = TRUE AND Email != NULL LIMIT 1];

    ProjetoBO.TaskProjectTableLine line = new ProjetoBO.TaskProjectTableLine();
    line.TipoDeProprietario = 'USUARIO';
    line.Responsavel = u.Email;

    Id result = TaskTemplateUtils.resolveOwner(line, new Map<String, User>(), null, null);
    Assert.isNotNull(result, 'Deve encontrar usuario por email.');
  }

  @IsTest
  static void shouldParseIntegerNullReturnsDefault() {
    Assert.areEqual(10, TaskTemplateUtils.parseInteger(null, 10));
    Assert.areEqual(0, TaskTemplateUtils.parseInteger('', 0));
  }
}
