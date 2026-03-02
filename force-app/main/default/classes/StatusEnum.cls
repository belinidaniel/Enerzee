public class StatusEnum {
  public static Map<String, Integer> PipelineEnum = new Map<String, Integer>{
    'ProspectCriado' => 1,
    'GerandoProposta' => 2,
    'PropostaEmRevisao' => 3,
    'PropostaGerada' => 4,
    'Viabilidade' => 6,
    'Contrato' => 7,
    'Pagamento' => 8,
    'AprovacaoPagamento' => 13,
    'Implantacao' => 9,
    'Finalizado' => 10,
    'Encerradas' => 12
  };

  public static Map<String, Integer> EzeeLivreEnum = new Map<String, Integer>{
    'Prospecção' => 14,
    'Aguardando Informação' => 15,
    'Elaboração de Estudo' => 16,
    'Agendamento Pendente' => 17,
    'Reunião Agendada' => 18,
    'Negociação' => 19,
    'Minuta Gerada' => 20,
    'Finalizado (Aguard. NF)' => 21,
    'Aguardando Pagamento' => 22,
    'Pagamento Confirmado' => 23,
    'Ganho fechado' => 24,
    'Fechado Perdido' => 25
  };

  public static Map<String, Integer> EzeeConnectEnum = new Map<String, Integer>{
    'Backlog' => 26,
    'Aguardando Informação' => 27,
    'Elaboração de proposta' => 28,
    'Aguard. Assinatura (Bow-e)' => 29,
    'Negociação (PLIN)' => 30,
    'Aguard. Assinatura (PLIN)' => 31,
    'Aguard. Assinatura (Raízen)' => 32,
    'Finalizado (Aguardad. NF)' => 33,
    'Aguardando Pagamento' => 34,
    'Ganho fechado' => 35,
    'Fechado Perdido' => 36
  };

  public static Map<String, Integer> EzeeSolarEnum = new Map<String, Integer>{
    'Elaboração de proposta' => 37,
    'Proposta enviada / Aguardando Aceite' => 38,
    'Análise de Crédito' => 39,
    'Contrato firmado / Assinado' => 40,
    'Análise de viabilidade' => 41,
    'Aprovacao De Projeto' => 42,
    'Aguardando Equipamento' => 43,
    'Fase De Obra' => 44,
    'Finalizado (Aguardad. NF)' => 45,
    'Fechado Perdido' => 46
  };

  public static Integer getStatusEnum(
    String recordTypeName,
    String statusValue
  ) {
    Map<String, Integer> selectedEnum;

    if (recordTypeName == 'ezeelivre') {
      selectedEnum = EzeeLivreEnum;
    } else if (recordTypeName == 'ezeeconnect') {
      selectedEnum = EzeeConnectEnum;
    } else if (recordTypeName == 'ezeesolar') {
      selectedEnum = EzeeSolarEnum;
    } else {
      throw new IllegalArgumentException('Invalid record type name');
    }

    if (selectedEnum.containsKey(statusValue)) {
      return selectedEnum.get(statusValue);
    } else {
      throw new IllegalArgumentException(
        'Invalid status value for the given record type'
      );
    }
  }
}
