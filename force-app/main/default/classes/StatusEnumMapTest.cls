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
    Assert.areEqual(
      54,
      StatusEnumMap.getStatusEnum('Ezee Livre', 'Validação'),
      'Ezee Livre Validação deve ter Id APP 54'
    );
  }

  @IsTest
  static void shouldMapProposalTypes() {
    Assert.areEqual(
      1,
      StatusEnumMap.getProposalTypeEnum('Solar'),
      'Solar deve ter ProposalType 1'
    );
    Assert.areEqual(
      2,
      StatusEnumMap.getProposalTypeEnum('Ezee Solar - Grupo A'),
      'Ezee Solar - Grupo A deve ter ProposalType 2'
    );
    Assert.areEqual(
      3,
      StatusEnumMap.getProposalTypeEnum('Ezee Solar - Grupo B'),
      'Ezee Solar - Grupo B deve ter ProposalType 3'
    );
    Assert.areEqual(
      4,
      StatusEnumMap.getProposalTypeEnum('Ezee Connect'),
      'Ezee Connect deve ter ProposalType 4'
    );
    Assert.areEqual(
      5,
      StatusEnumMap.getProposalTypeEnum('Ezee Livre'),
      'Ezee Livre deve ter ProposalType 5'
    );
    Assert.areEqual(
      6,
      StatusEnumMap.getProposalTypeEnum('Produtos'),
      'Produtos deve ter ProposalType 6'
    );
    Assert.areEqual(
      7,
      StatusEnumMap.getProposalTypeEnum('Serviços'),
      'Serviços deve ter ProposalType 7'
    );
    Assert.areEqual(
      8,
      StatusEnumMap.getProposalTypeEnum('Serviços EPC'),
      'Serviços EPC deve ter ProposalType 8'
    );
    Assert.areEqual(
      0,
      StatusEnumMap.getProposalTypeEnum('Desconhecido'),
      'RecordType desconhecido deve retornar 0'
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
    Assert.areEqual(
      78,
      StatusEnumMap.getSubstatusEnum(54, 'Em Andamento'),
      'Ezee Livre Validação SubStatus Em Andamento deve ter Id APP 78'
    );
    Assert.areEqual(
      79,
      StatusEnumMap.getSubstatusEnum(54, 'Pendência'),
      'Ezee Livre Validação SubStatus Pendência deve ter Id APP 79'
    );
  }
}
