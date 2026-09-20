---
status: stable
last_updated: 2026-09-12
---

# Lançamento — lista das últimas entradas + edit modal + novo

Página com as 10 últimas linhas inseridas na planilha, em ordem de inserção (mais recente primeiro). Cada item abre um modal de edição. No Flutter (Bloom), uma segunda aba `+ Novo` permite criar lançamentos manualmente via `addEntry`.

> **Flutter (Bloom)**: 2 tabs (`Lançamentos` + `+ Novo`). PWA legada tem só a lista (sem tab Novo).

## Contexto

Foco em corrigir lançamentos automáticos — o webhook insere com classificação inferida; o usuário muitas vezes precisa ajustar `categoria`, `rateio`, ou marcar parcela. Sem essa página, o usuário teria que abrir a planilha no Sheets — atrito alto.

## Regras

### Inputs / data

- `useLastEntries(10)` → últimos 10 entries com `row` (sheet row 1-indexed).
- `useMonthData(currentMonth)` → para sugerir `categoria` no autocomplete do modal. Usa `currentMonth` do StickyHeader em modo "disabled" (sempre fatura mais recente — não a selecionada pelo usuário).

### StickyHeader em modo disabled

A página de Lançamento monta uma instância **própria** do StickyHeader com `disabled={true}`. Ele:
- Faz `useMonthData(null)` (sempre o mais recente, ignorando `currentMonth` do store).
- Mostra o mês fixo (não permite trocar).
- Mantém os 3 tiles (Total geral, Total cartão, Total parcelado) calculados sobre essa fatura.

Razão: editar um lançamento só faz sentido se você está vendo a fatura corrente (lançamentos novos vão sempre nela). Permitir mudar o filtro de mês confundiria.

### Tabs (Flutter, Bloom)

Apenas no Flutter:
- **`Lançamentos`** (default) — listagem (descrita abaixo).
- **`+ Novo`** — form funcional para criar entradas manualmente via `addEntry`. Hero gradient com `TextField` editável (valor R$). Abaixo:
  - **Mês Fatura** (pós-2026-05-12) — `_MonthYearTap` que abre `showMonthYearPicker` (dois dropdowns Mês + Ano). Default = mês corrente. Salva sempre com `day=6`. Send: `data: "06/MM/YYYY"`.
  - **Estabelecimento** (TextField, obrigatório).
  - **Categoria** (Autocomplete; sugestões = `monthData.rows[*].categoria` deduped+sort).
  - **Forma** (segmented `Crédito`/`Débito` → envia o valor literal da col E). Até 2026-09-20 era `Cartão`/`Pix`, mapeando `Pix` → `"Pix (contas)"`.
  - **Divisão** (segmented `Metade`/`Júlio`/`Dani`/`Alzira` → envia como `rateio`).
  - **Parcela** (stepper 1..99 — só renderiza se Forma=`Crédito`). Default 1 (à vista).
  - **Banco** (segmented `Santander`/`Revolut`, só se Forma=`Crédito`). **Sem default** — obrigatório escolher; validação local "Selecione o banco." se vazio ao salvar. Envia `banco`. Substituiu o TextField "Cartão (4 dígitos)" em 2026-09-12.
  - **Marcar para Acerto Final** (Switch, só se Forma=`Pix`; envia `acerto: "Sim"`).
  - **Salvar lançamento** → `api.addEntry(...)`. Loading state desabilita botão. Erro (server ou validação local) aparece em pílula vermelha.
- **Defaults enviados ao backend**: `data` sempre enviada (pós-2026-05-12) — `dataRef` omitido → o Apps Script usa agora no TZ. `categoria` vazia OK. `banco` vazio quando Forma=`Pix`. `parcela` enviado como `"1/N"` quando N>1, senão `""`.
- **On success**: SnackBar verde "Lançamento criado.", `ref.invalidate(lastEntriesProvider)` + `ref.invalidate(monthDataProvider)`, e `widget.onCancel()` volta pra aba `Lançamentos`.

### Lista de entries (PWA legada)

Cada entry renderiza como um botão (`<button>`):

```
[dataRef] · [origem]
[descricao]                    R$ [valor]
[categoria pill] [rateio pill] [parcela pill se total > 1]
```

- Pills `categoria` e `rateio`: cor base (`bg-[#f0ece2]`). Só aparecem se não-vazias.
- Pill de parcela: cor de destaque (`bg-accent text-accent-fg`). Aparece só se `parcelaTotal(parcela) > 1`. Mostra `e.parcela` verbatim (ex.: `"1/3"`).

Click → abre modal com essa entry.

### Lista de entries (Flutter, Bloom)

Cada entry é um `RecentEntryRow` (widget compartilhado — ver [../cards/recent-entry-row.md](../cards/recent-entry-row.md)). O avatar mostra o **rateio** (não a 1ª letra da descrição) com cor por rateio; quando `entry.parcela` está preenchida, a linha de metadados inclui `· (X / Y)`. `highlightMissing: true` aplica tom vermelho quando `categoria` ou `rateio` estão vazios — sobrepõe a regra de cor por rateio.

### Paginação (Flutter — pós-2026-05-11)

A lista inicial carrega **10** entradas. Ao final do `BloomCard` da lista, um `TextButton.icon "Carregar mais N"` (cor `BloomColors.violet`, ícone `Icons.expand_more`) carrega mais 10 por tap, até o cap de **100** total.

Implementação:
- `_editListLimitProvider` (StateProvider<int>, default 10) compartilhado entre `_LancamentoPageState._onRefresh` (pra await na refresh) e `_EditListState` (renderização e botão).
- Cache `_cachedEntries` em `_EditListState` (pós-2026-05-12): retém a última lista entregue pelo backend. Quando `_limit` muda e o provider novo (`lastEntriesProvider(novoLimit)`) ainda está carregando, `_cachedEntries` é usado como fallback — a lista permanece visível enquanto a nova página chega. Sem flicker de lista pra vazio.
- Flags do estado:
  - `initialLoading` = `isLoading && _cachedEntries.isEmpty` — só no primeiríssimo load (mostra spinner grande no card).
  - `reloading` = `isLoading && _cachedEntries.isNotEmpty` — durante "Carregar mais" subsequente (mostra spinner pequeno no lugar do botão).
  - `reachedSheetEnd` = `hasValue && !isLoading && entries.length < limit`.
  - `atCap` = `limit >= 100`.
  - `canLoadMore` = `!isLoading && !reachedSheetEnd && !atCap`.
- Fim/cap states:
  - `reloading=true` → spinner pequeno no rodapé (`CircularProgressIndicator` 20x20).
  - `canLoadMore=true` → botão "Carregar mais N" (N = `min(_step, _maxLimit - limit)`).
  - `atCap=true` → texto "Limite de 100 lançamentos atingido.".
  - `reachedSheetEnd=true` e `entries.length > 10` → texto "Fim da lista." (suprimido no primeiro carregamento).

Backend (`lastEntries` em `Dashboard.gs:218`) já aceita qualquer `n` — não precisou mudar. O cache do Riverpod usa `n` como chave de família, então cada incremento é um fetch limpo.

PWA legada (`web/`) não tem paginação — só os 10 últimos.

### Modal de edição

Componente `EditDialog` (Flutter) / `EditModal` (PWA legada).

**Editáveis (Flutter — após 2026-05-11):**

Ordem dos campos no modal, de cima pra baixo:

1. **Mês Fatura** (col A `data`) — display `monthYearShort(data)` (ex. "maio de 2026"); tap abre `showMonthYearPicker` (dialog custom com dois `DropdownButtonFormField`s: Mês 1-12 e Ano `[now.year-4 .. now.year+2]`). Após confirmação, `_data = DateTime(year, month, 6)` — dia sempre 06 (pós-2026-05-12; convenção: a coluna Data da planilha guarda o fechamento e o app padroniza dia 06 pra lançamentos UI-driven). Send: `data: "06/MM/YYYY"`.
2. **Data Referência** (col B `dataRef`) — dois chips lado-a-lado:
   - chip data: `showDatePicker` que preserva hora/minuto atuais.
   - chip hora: `showTimePicker` que preserva ano/mês/dia. Quando `_dataRef` é epoch sentinel (year < 2000), o picker de hora usa `DateTime.now()` como base de data para evitar serializar `"01/01/1970 HH:MM"`.
   - Send: `dataRef: "DD/MM/YYYY HH:MM"`.
3. **Origem** (col E) — `DropdownButtonFormField<String>` com `ADD_ENTRY_ORIGEMS` (`Crédito` | `Débito`). Se `entry.origem` vier fora do enum (legado), é adicionado como item extra prefixado `(?) <valor>` para correção sem perda. Send: `origem`.
4. Descrição (TextField).
5. Valor (R$, decimal).
6. Categoria (Autocomplete; sugestões = `monthData.rows[*].categoria` deduped+sort).
7. **Rateio** (col G) — Dropdown com `""` (exibido `(vazio)`), `Julio`, `Dani`, `Metade` (exibido `Metade (compartilhado)`), `Alzira`. Valor fora do enum (legado digitado direto na planilha) entra como item extra prefixado `(?) <valor>` — mesmo padrão de Origem e Banco. Sem isso o `DropdownButtonFormField` falha o assert de "exatamente um item com esse valor" e o modal **não abre**, deixando a linha ineditável justamente no app que serviria para corrigi-la (pós-2026-09-20).
8. **Banco** (col H) — `DropdownButtonFormField<String>` com `""` (vazio), `Santander`, `Revolut`. Só renderiza quando `_origem == "Cartão"`. Se `entry.banco` vier fora do enum (legado numérico, ex. `"784"`), é adicionado como item extra prefixado `(?) 784` para correção sem perda — mesmo padrão do campo Origem. Send: `banco` (`""` quando Origem ≠ Cartão). Pós-2026-09-12.
9. Parcela (stepper 1..99 — ver [parcela-format.md](../rules/parcela-format.md)).

**Read-only fields:** nenhum (era `Data de referência` + `Origem`; ambos viraram editáveis em 2026-05-11).

**PWA legada (`web/`)** mantém o comportamento antigo com read-only fields. Não tocar — codebase congelado.

#### Parcela math no modal

Ao abrir:
- `originalTotal = entry.valor * parcelaTotal(entry.parcela)`.

Stepper `±`:
- Clamp `parcela` em `[1, 99]`.
- `valor = originalTotal / parcela`.

Edição manual de valor:
- `originalTotal = valor * parcela`.

Display: `{parcela}x` no centro do stepper. Abaixo: `Total da compra: R$ {formatMoney(originalTotal)}` (atualiza em tempo real).

### Save

- Body Flutter (pós-2026-09-12): `{ row: entry.row, fields: { descricao, valor, categoria, rateio, parcela, data: "DD/MM/YYYY", dataRef: "DD/MM/YYYY HH:MM", origem, banco } }` — todos enviados sempre (`banco` pode ser `""`). Validados no backend; erros `missing_data`/`missing_dataRef`/`missing_origem`/`invalid_origem`/`invalid_banco`.
- Body PWA legada: contrato antigo (5 campos), inalterado.
- Mutation: `useUpdateEntry`. `onSuccess` invalida `["lastEntries"]` e `["monthData"]`.
- Após sucesso: `onClose()` → fecha modal.

### Delete

- Confirma com `window.confirm("Excluir este lançamento? Esta ação não pode ser desfeita.")`.
- Se confirmado: `useDeleteEntry`. Invalida as mesmas queries.
- Após sucesso: `onClose()`.

### Erros

- HTTP/server error: exibe `"Erro: <mensagem>"` em vermelho dentro do modal. Não fecha.
- Botões ficam disabled durante mutation pending.

## Edge cases

- **Sem lançamentos**: lista mostra `"Sem lançamentos."` após loading.
- **`monthData` ainda carregando** quando o modal abre: datalist de categoria vazio. OK — usuário pode digitar livre.
- **Concorrência**: usuário edita uma linha, webhook insere outra ao mesmo tempo. As mutations invalidam cache; a próxima leitura pega tudo. Sem optimistic update.
- **Parcela = 1 quando entry tinha `"3"` (legado):** save converte para `""`. Esperado.
- **Stepper em 1:** botão `−` ainda funciona mas clamp em 1.

## Implementações

- **PWA:** [web/src/pages/LancamentoPage.tsx](../../../web/src/pages/LancamentoPage.tsx) + [web/src/components/EditModal.tsx](../../../web/src/components/EditModal.tsx).
- **Hooks:** [useLastEntries.ts](../../../web/src/hooks/useLastEntries.ts) — `useLastEntries`, `useUpdateEntry`, `useDeleteEntry`.
- **Após Onda 2:** parcela math em `EditModal` move helpers para `core/rules/parcela.ts`. JSX permanece.
- **Flutter:** [app/lib/features/lancamento/lancamento_page.dart](../../../app/lib/features/lancamento/lancamento_page.dart) com 2 tabs (`Lançamentos` + `+ Novo` stub); `Dialog` para edit modal; mesma math.

## Specs relacionadas

- [../rules/parcela-format.md](../rules/parcela-format.md)
- [../api/endpoints.md](../api/endpoints.md) — `lastEntries`, `updateEntry`, `deleteEntry`
- [../state/persistence.md](../state/persistence.md)
