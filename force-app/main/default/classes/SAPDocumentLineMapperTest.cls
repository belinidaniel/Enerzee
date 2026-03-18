/**
 * @description       : TDD tests for SAPDocumentLineMapper — all mapping branches
 * @author            : Daniel Belini
 * @group             : SAP Integration
 * @last modified on  : 03-17-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class SAPDocumentLineMapperTest {
  // ── getMeasureUnitId ─────────────────────────────────────────────────────

  @IsTest
  static void getMeasureUnitId_givenMetro_thenReturnsM() {
    // Given: unidade de medida 'Metro'
    // When: mapeamento executado
    // Then: retorna 'm'
    Assert.areEqual('m', SAPDocumentLineMapper.getMeasureUnitId('Metro'));
  }

  @IsTest
  static void getMeasureUnitId_givenMetroQuadrados_thenReturnsM2() {
    Assert.areEqual(
      'm2',
      SAPDocumentLineMapper.getMeasureUnitId('Metro Quadrados')
    );
  }

  @IsTest
  static void getMeasureUnitId_givenKilograma_thenReturnsKg() {
    Assert.areEqual('kg', SAPDocumentLineMapper.getMeasureUnitId('Kilograma'));
  }

  @IsTest
  static void getMeasureUnitId_givenSegundos_thenReturnsS() {
    Assert.areEqual('s', SAPDocumentLineMapper.getMeasureUnitId('Segundos'));
  }

  @IsTest
  static void getMeasureUnitId_givenHoras_thenReturnsH() {
    Assert.areEqual('h', SAPDocumentLineMapper.getMeasureUnitId('Horas'));
  }

  @IsTest
  static void getMeasureUnitId_givenDia_thenReturnsD() {
    Assert.areEqual('d', SAPDocumentLineMapper.getMeasureUnitId('Dia'));
  }

  @IsTest
  static void getMeasureUnitId_givenUnidade_thenReturnsUN() {
    Assert.areEqual('UN', SAPDocumentLineMapper.getMeasureUnitId('Unidade'));
  }

  @IsTest
  static void getMeasureUnitId_givenServico_thenReturnsSV() {
    Assert.areEqual('SV', SAPDocumentLineMapper.getMeasureUnitId('Serviço'));
  }

  @IsTest
  static void getMeasureUnitId_givenUnknown_thenReturnsSV() {
    // Given: valor desconhecido → default SAP
    Assert.areEqual(
      'SV',
      SAPDocumentLineMapper.getMeasureUnitId('ValorInvalido')
    );
  }

  @IsTest
  static void getMeasureUnitId_givenNull_thenReturnsSV() {
    Assert.areEqual('SV', SAPDocumentLineMapper.getMeasureUnitId(null));
  }

  @IsTest
  static void getMeasureUnitId_isCaseInsensitive() {
    // Given: mesma string em case diferente
    Assert.areEqual('m', SAPDocumentLineMapper.getMeasureUnitId('METRO'));
    Assert.areEqual('UN', SAPDocumentLineMapper.getMeasureUnitId('unidade'));
  }

  // ── getMeasurementById ───────────────────────────────────────────────────

  @IsTest
  static void getMeasurementById_givenValor_thenReturns1() {
    // Given: tipo de medição 'Valor'
    // When: mapeamento executado
    // Then: retorna 1 (código SAP para medição por valor)
    Assert.areEqual(1, SAPDocumentLineMapper.getMeasurementById('Valor'));
  }

  @IsTest
  static void getMeasurementById_givenPercentual_thenReturns2() {
    Assert.areEqual(2, SAPDocumentLineMapper.getMeasurementById('Percentual'));
  }

  @IsTest
  static void getMeasurementById_givenQuantidade_thenReturns3() {
    Assert.areEqual(3, SAPDocumentLineMapper.getMeasurementById('Quantidade'));
  }

  @IsTest
  static void getMeasurementById_givenUnknown_thenReturns3() {
    Assert.areEqual(3, SAPDocumentLineMapper.getMeasurementById('Outro'));
  }

  @IsTest
  static void getMeasurementById_givenNull_thenReturns3() {
    Assert.areEqual(3, SAPDocumentLineMapper.getMeasurementById(null));
  }

  // ── getBillingType ───────────────────────────────────────────────────────

  @IsTest
  static void getBillingType_givenNenhum_thenReturns0() {
    // Given: tipo de faturamento 'Nenhum'
    // When: mapeamento executado
    // Then: retorna 0 (código SAP sem faturamento)
    Assert.areEqual(0, SAPDocumentLineMapper.getBillingType('Nenhum'));
  }

  @IsTest
  static void getBillingType_givenMedicao_thenReturns1() {
    Assert.areEqual(1, SAPDocumentLineMapper.getBillingType('Medição'));
  }

  @IsTest
  static void getBillingType_givenParcelado_thenReturns2() {
    Assert.areEqual(2, SAPDocumentLineMapper.getBillingType('Parcelado'));
  }

  @IsTest
  static void getBillingType_givenRecorrente_thenReturns3() {
    Assert.areEqual(3, SAPDocumentLineMapper.getBillingType('Recorrente'));
  }

  @IsTest
  static void getBillingType_givenCalculado_thenReturns4() {
    Assert.areEqual(4, SAPDocumentLineMapper.getBillingType('Calculado'));
  }

  @IsTest
  static void getBillingType_givenParceladoMedido_thenReturns5() {
    Assert.areEqual(
      5,
      SAPDocumentLineMapper.getBillingType('Parcelado Medido')
    );
  }

  @IsTest
  static void getBillingType_givenUnknown_thenReturns5() {
    Assert.areEqual(5, SAPDocumentLineMapper.getBillingType('ValorInvalido'));
  }

  @IsTest
  static void getBillingType_givenNull_thenReturns5() {
    Assert.areEqual(5, SAPDocumentLineMapper.getBillingType(null));
  }

  // ── getRecurrenceType ────────────────────────────────────────────────────

  @IsTest
  static void getRecurrenceType_givenIndefinida_thenReturns0() {
    // Given: recorrência indefinida (sem fim)
    // When: mapeamento executado
    // Then: retorna 0
    Assert.areEqual(0, SAPDocumentLineMapper.getRecurrenceType('Indefinida'));
  }

  @IsTest
  static void getRecurrenceType_givenNaoSeAplica_thenReturns1() {
    Assert.areEqual(
      1,
      SAPDocumentLineMapper.getRecurrenceType('Não se aplica')
    );
  }

  @IsTest
  static void getRecurrenceType_givenMensal_thenReturns2() {
    Assert.areEqual(2, SAPDocumentLineMapper.getRecurrenceType('Mensal'));
  }

  @IsTest
  static void getRecurrenceType_givenAnual_thenReturns3() {
    Assert.areEqual(3, SAPDocumentLineMapper.getRecurrenceType('Anual'));
  }

  @IsTest
  static void getRecurrenceType_givenBimestral_thenReturns4() {
    Assert.areEqual(4, SAPDocumentLineMapper.getRecurrenceType('Bimestral'));
  }

  @IsTest
  static void getRecurrenceType_givenTrimestral_thenReturns5() {
    Assert.areEqual(5, SAPDocumentLineMapper.getRecurrenceType('Trimestral'));
  }

  @IsTest
  static void getRecurrenceType_givenSemestral_thenReturns6() {
    Assert.areEqual(6, SAPDocumentLineMapper.getRecurrenceType('Semestral'));
  }

  @IsTest
  static void getRecurrenceType_givenUnknown_thenReturns6() {
    Assert.areEqual(
      6,
      SAPDocumentLineMapper.getRecurrenceType('ValorInvalido')
    );
  }

  @IsTest
  static void getRecurrenceType_givenNull_thenReturns6() {
    Assert.areEqual(6, SAPDocumentLineMapper.getRecurrenceType(null));
  }

  // ── getClassification ────────────────────────────────────────────────────

  @IsTest
  static void getClassification_givenContratosLocacao_thenReturns1() {
    // Given: classificação de contrato de locação
    // When: mapeamento executado
    // Then: retorna 1 (código SAP para locação)
    Assert.areEqual(
      1,
      SAPDocumentLineMapper.getClassification('Contratos de Locação')
    );
  }

  @IsTest
  static void getClassification_givenContratosServicos_thenReturns2() {
    Assert.areEqual(
      2,
      SAPDocumentLineMapper.getClassification('Contratos de Serviços')
    );
  }

  @IsTest
  static void getClassification_givenContratosLicenciamento_thenReturns3() {
    Assert.areEqual(
      3,
      SAPDocumentLineMapper.getClassification('Contratos de Licenciamento')
    );
  }

  @IsTest
  static void getClassification_givenComprasEquipamentos_thenReturns4() {
    Assert.areEqual(
      4,
      SAPDocumentLineMapper.getClassification(
        'Compras de equipamentos e materiais'
      )
    );
  }

  @IsTest
  static void getClassification_givenArrendamentoRural_thenReturns5() {
    Assert.areEqual(
      5,
      SAPDocumentLineMapper.getClassification('Arrendamento de área rural')
    );
  }

  @IsTest
  static void getClassification_givenPrestacaoServicos_thenReturns6() {
    Assert.areEqual(
      6,
      SAPDocumentLineMapper.getClassification('Prestação de Serviços (v)')
    );
  }

  @IsTest
  static void getClassification_givenVendaEquipamentos_thenReturns7() {
    Assert.areEqual(
      7,
      SAPDocumentLineMapper.getClassification(
        'Venda de equipamentos e materiais'
      )
    );
  }

  @IsTest
  static void getClassification_givenUnknown_thenReturns7() {
    Assert.areEqual(7, SAPDocumentLineMapper.getClassification('Outro'));
  }

  @IsTest
  static void getClassification_givenNull_thenReturns7() {
    Assert.areEqual(7, SAPDocumentLineMapper.getClassification(null));
  }
}
