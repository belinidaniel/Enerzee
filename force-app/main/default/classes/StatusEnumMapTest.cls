/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class StatusEnumMapTest {
  @IsTest
  static void shouldMapStatuses() {
    System.assertEquals(
      1,
      StatusEnumMap.getStatusEnum('Solar', 'Elaboração de proposta')
    );
    System.assertEquals(
      12,
      StatusEnumMap.getStatusEnum('Ezee Solar - Grupo A', 'Proposta enviada')
    );
    System.assertEquals(
      21,
      StatusEnumMap.getStatusEnum('Ezee Solar - Grupo B', 'Análise de Crédito')
    );
    System.assertEquals(
      28,
      StatusEnumMap.getStatusEnum('Ezee Connect', 'Proposta enviada')
    );
    System.assertEquals(
      0,
      StatusEnumMap.getStatusEnum('Ezee Livre', 'Inexistente')
    );
  }

  @IsTest
  static void shouldMapSubstatuses() {
    System.assertEquals(2, StatusEnumMap.getSubstatusEnum(3, 'Pago'));
    System.assertEquals(
      24,
      StatusEnumMap.getSubstatusEnum(18, 'Entrega de materiais')
    );
    System.assertEquals(0, StatusEnumMap.getSubstatusEnum(999, 'Desconhecido'));
  }
}
