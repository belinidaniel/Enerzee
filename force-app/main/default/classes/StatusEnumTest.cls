@IsTest
private class StatusEnumTest {
  @IsTest
  static void shouldReturnMappedValues() {
    System.assertEquals(
      14,
      StatusEnum.getStatusEnum('ezeelivre', 'Prospecção')
    );
    System.assertEquals(26, StatusEnum.getStatusEnum('ezeeconnect', 'Backlog'));
    System.assertEquals(
      37,
      StatusEnum.getStatusEnum('ezeesolar', 'Elaboração de proposta')
    );
  }

  @IsTest
  static void shouldThrowForInvalidRecordType() {
    try {
      StatusEnum.getStatusEnum('invalid', 'Prospecção');
      System.assert(false, 'Expected exception for invalid record type');
    } catch (Exception e) {
      System.assertEquals('Invalid record type name', e.getMessage());
    }
  }

  @IsTest
  static void shouldThrowForInvalidStatus() {
    try {
      StatusEnum.getStatusEnum('ezeelivre', 'Inexistente');
      System.assert(false, 'Expected exception for invalid status');
    } catch (Exception e) {
      System.assertEquals(
        'Invalid status value for the given record type',
        e.getMessage()
      );
    }
  }
}
