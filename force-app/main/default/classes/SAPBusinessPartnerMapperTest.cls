/**
 * @description       : TDD tests for SAPBusinessPartnerMapper
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-18-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@IsTest
private class SAPBusinessPartnerMapperTest {
  // ── normalizeState ──────────────────────────────────────────────────────────

  @IsTest
  static void normalizeState_givenNull_thenReturnsNull() {
    Assert.areEqual(null, SAPBusinessPartnerMapper.normalizeState(null));
  }

  @IsTest
  static void normalizeState_givenTwoCharAbbreviation_thenReturnsAsIs() {
    Assert.areEqual('SP', SAPBusinessPartnerMapper.normalizeState('SP'));
  }

  @IsTest
  static void normalizeState_givenSaoPaulo_thenReturnsSP() {
    Assert.areEqual('SP', SAPBusinessPartnerMapper.normalizeState('São Paulo'));
  }

  @IsTest
  static void normalizeState_givenMinasGerais_thenReturnsMG() {
    Assert.areEqual(
      'MG',
      SAPBusinessPartnerMapper.normalizeState('Minas Gerais')
    );
  }

  @IsTest
  static void normalizeState_givenRioDeJaneiro_thenReturnsRJ() {
    Assert.areEqual(
      'RJ',
      SAPBusinessPartnerMapper.normalizeState('Rio de Janeiro')
    );
  }

  @IsTest
  static void normalizeState_givenUnknownFullName_thenReturnsNull() {
    Assert.areEqual(
      null,
      SAPBusinessPartnerMapper.normalizeState('Estado Inexistente')
    );
  }

  // ── normalizeCountry ────────────────────────────────────────────────────────

  @IsTest
  static void normalizeCountry_givenNull_thenReturnsNull() {
    Assert.areEqual(null, SAPBusinessPartnerMapper.normalizeCountry(null));
  }

  @IsTest
  static void normalizeCountry_givenBrasil_thenReturnsBR() {
    Assert.areEqual('BR', SAPBusinessPartnerMapper.normalizeCountry('Brasil'));
  }

  @IsTest
  static void normalizeCountry_givenBrasilUpperCase_thenReturnsBR() {
    Assert.areEqual('BR', SAPBusinessPartnerMapper.normalizeCountry('BRASIL'));
  }

  @IsTest
  static void normalizeCountry_givenBRAlready_thenReturnsAsIs() {
    Assert.areEqual('BR', SAPBusinessPartnerMapper.normalizeCountry('BR'));
  }

  @IsTest
  static void normalizeCountry_givenOtherCountry_thenReturnsAsIs() {
    Assert.areEqual('US', SAPBusinessPartnerMapper.normalizeCountry('US'));
  }

  // ── buildBillingAddress ─────────────────────────────────────────────────────

  @IsTest
  static void buildBillingAddress_givenAllFields_thenReturnsCorrectAddress() {
    SAPBusinessPartnerMapper.BPAddress addr = SAPBusinessPartnerMapper.buildBillingAddress(
      '12345678000100',
      'Rua das Flores',
      '100',
      'Centro',
      '01310-100',
      'São Paulo',
      'São Paulo',
      'BR',
      'SP',
      'Apto 2'
    );

    Assert.areEqual('Endereço cobrança', addr.AddressName);
    Assert.areEqual('bo_BillTo', addr.AddressType);
    Assert.areEqual(0, addr.RowNum);
    Assert.areEqual('12345678000100', addr.BPCode);
    Assert.areEqual('Rua das Flores', addr.Street);
    Assert.areEqual('100', addr.StreetNo);
    Assert.areEqual('Centro', addr.Block);
    Assert.areEqual('01310-100', addr.ZipCode);
    Assert.areEqual('São Paulo', addr.City);
    Assert.areEqual('São Paulo', addr.County);
    Assert.areEqual('BR', addr.Country);
    Assert.areEqual('SP', addr.State);
    Assert.areEqual('Apto 2', addr.BuildingFloorRoom);
  }

  @IsTest
  static void buildBillingAddress_givenNullComplement_thenBuildingFloorRoomIsEmpty() {
    SAPBusinessPartnerMapper.BPAddress addr = SAPBusinessPartnerMapper.buildBillingAddress(
      '123',
      'Rua A',
      '1',
      'Bairro',
      '12345-000',
      'Cidade',
      'Cidade',
      'BR',
      'SP',
      null
    );
    Assert.areEqual('', addr.BuildingFloorRoom);
  }

  // ── buildShippingAddress ────────────────────────────────────────────────────

  @IsTest
  static void buildShippingAddress_givenAllFields_thenReturnsCorrectAddress() {
    SAPBusinessPartnerMapper.BPAddress addr = SAPBusinessPartnerMapper.buildShippingAddress(
      '12345678000100',
      'Av. Brasil',
      '500',
      'Jardins',
      '04538-133',
      'São Paulo',
      'São Paulo',
      'BR',
      'SP',
      'Bloco B'
    );

    Assert.areEqual('Endereço entrega', addr.AddressName);
    Assert.areEqual('bo_ShipTo', addr.AddressType);
    Assert.areEqual(1, addr.RowNum);
    Assert.areEqual('12345678000100', addr.BPCode);
    Assert.areEqual('Av. Brasil', addr.Street);
    Assert.areEqual('500', addr.StreetNo);
    Assert.areEqual('Jardins', addr.Block);
    Assert.areEqual('04538-133', addr.ZipCode);
    Assert.areEqual('São Paulo', addr.City);
    Assert.areEqual('BR', addr.Country);
    Assert.areEqual('SP', addr.State);
    Assert.areEqual('Bloco B', addr.BuildingFloorRoom);
  }

  @IsTest
  static void buildShippingAddress_givenNullComplement_thenBuildingFloorRoomIsEmpty() {
    SAPBusinessPartnerMapper.BPAddress addr = SAPBusinessPartnerMapper.buildShippingAddress(
      '123',
      'Rua B',
      '2',
      'Bairro',
      '12345-000',
      'Cidade',
      'Cidade',
      'BR',
      'SP',
      null
    );
    Assert.areEqual('', addr.BuildingFloorRoom);
  }

  // ── buildFiscalTaxId ────────────────────────────────────────────────────────

  @IsTest
  static void buildFiscalTaxId_givenCPF_thenTaxID0IsSet() {
    SAPBusinessPartnerMapper.BPFiscalTaxID taxId = SAPBusinessPartnerMapper.buildFiscalTaxId(
      '12345678901',
      null,
      '12345678901'
    );
    Assert.areEqual('12345678901', taxId.TaxID0);
    Assert.areEqual(null, taxId.TaxID4);
  }

  @IsTest
  static void buildFiscalTaxId_givenCNPJ_thenTaxID4IsSet() {
    SAPBusinessPartnerMapper.BPFiscalTaxID taxId = SAPBusinessPartnerMapper.buildFiscalTaxId(
      null,
      '12345678000100',
      '12345678000100'
    );
    Assert.areEqual(null, taxId.TaxID0);
    Assert.areEqual('12345678000100', taxId.TaxID4);
  }

  @IsTest
  static void buildFiscalTaxId_givenNeitherCPFNorCNPJ_thenBothNull() {
    SAPBusinessPartnerMapper.BPFiscalTaxID taxId = SAPBusinessPartnerMapper.buildFiscalTaxId(
      null,
      null,
      null
    );
    Assert.areEqual(null, taxId.TaxID0);
    Assert.areEqual(null, taxId.TaxID4);
  }

  @IsTest
  static void buildFiscalTaxId_givenCPFTakesPrecedenceOverCNPJ_thenTaxID0IsSet() {
    SAPBusinessPartnerMapper.BPFiscalTaxID taxId = SAPBusinessPartnerMapper.buildFiscalTaxId(
      '12345678901',
      '12345678000100',
      '12345678901'
    );
    Assert.areEqual('12345678901', taxId.TaxID0);
    Assert.areEqual(null, taxId.TaxID4);
  }
}
