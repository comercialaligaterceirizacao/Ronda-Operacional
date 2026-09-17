import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const apiDefault = 'http://10.0.2.2:3000/api';

void main() => runApp(const AlmoxApp());

class AlmoxApp extends StatelessWidget {
  const AlmoxApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'A Liga Almoxarifado',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: const LoginPage(),
    );
  }
}

class Api {
  static Future<String> base() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('api') ?? apiDefault;
  }

  static Future<dynamic> request(String method, String path, [Map<String, dynamic>? data]) async {
    final url = Uri.parse('${await base()}$path');
    final headers = {'Content-Type': 'application/json'};
    http.Response r;
    if (method == 'GET') {
      r = await http.get(url);
    } else if (method == 'POST') {
      r = await http.post(url, headers: headers, body: jsonEncode(data ?? {}));
    } else {
      r = await http.patch(url, headers: headers, body: jsonEncode(data ?? {}));
    }
    if (r.statusCode >= 400) throw Exception(r.body);
    return r.body.isEmpty ? {} : jsonDecode(r.body);
  }

  static Future<List<dynamic>> list(String path) async {
    final r = await http.get(Uri.parse('${await base()}$path'));
    if (r.statusCode >= 400) throw Exception(r.body);
    return List<dynamic>.from(jsonDecode(r.body));
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usuario = TextEditingController(text: 'supervisor');
  final senha = TextEditingController(text: '1234');
  final api = TextEditingController(text: apiDefault);
  bool carregando = false;
  String? erro;

  Future<void> entrar() async {
    setState(() { carregando = true; erro = null; });
    try {
      final p = await SharedPreferences.getInstance();
      final base = api.text.trim().replaceFirst(RegExp(r'\/$'), '');
      await p.setString('api', base);
      final user = Map<String, dynamic>.from(await Api.request('POST', '/login', {
        'usuario': usuario.text.trim(),
        'senha': senha.text,
      }));
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage(user: user)));
    } catch (e) {
      if (mounted) setState(() => erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2, size: 72),
                const SizedBox(height: 12),
                const Text('A Liga Almoxarifado', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: usuario, decoration: const InputDecoration(labelText: 'Usuário', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: senha, obscureText: true, decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: api, decoration: const InputDecoration(labelText: 'Servidor/API', border: OutlineInputBorder())),
                if (erro != null) Padding(padding: const EdgeInsets.all(8), child: Text(erro!, style: const TextStyle(color: Colors.red))),
                SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: carregando ? null : entrar, child: Text(carregando ? 'Entrando...' : 'ENTRAR'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  const HomePage({super.key, required this.user});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int aba = 0;
  List<dynamic> requisicoes = [];
  bool carregando = false;

  @override
  void initState() { super.initState(); carregar(); }

  Future<void> carregar() async {
    setState(() => carregando = true);
    try {
      final usuario = widget.user['usuario']?.toString() ?? '';
      requisicoes = await Api.list('/requisicoes?usuario=${Uri.encodeComponent(usuario)}');
    } catch (_) {}
    if (mounted) setState(() => carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.user['perfil'] == 'almoxarifado';
    return Scaffold(
      appBar: AppBar(
        title: Text(admin ? 'Painel do Almoxarifado' : 'A Liga Almoxarifado'),
        actions: [IconButton(onPressed: carregar, icon: const Icon(Icons.refresh))],
      ),
      body: carregando && requisicoes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : aba == 0
              ? (admin ? AdminPage(requisicoes: requisicoes, recarregar: carregar) : NovaRequisicao(user: widget.user, recarregar: carregar))
              : Historico(requisicoes: requisicoes, admin: admin, recarregar: carregar),
      bottomNavigationBar: NavigationBar(
        selectedIndex: aba,
        onDestinationSelected: (v) => setState(() => aba = v),
        destinations: [
          NavigationDestination(icon: Icon(admin ? Icons.dashboard : Icons.add_box), label: admin ? 'Painel' : 'Nova'),
          const NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
        ],
      ),
    );
  }
}

class NovaRequisicao extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback recarregar;
  const NovaRequisicao({super.key, required this.user, required this.recarregar});
  @override
  State<NovaRequisicao> createState() => _NovaRequisicaoState();
}

class _NovaRequisicaoState extends State<NovaRequisicao> {
  final keyForm = GlobalKey<FormState>();
  final empresa = TextEditingController();
  final funcionario = TextEditingController();
  final produto = TextEditingController();
  final quantidade = TextEditingController(text: '1');
  final tamanho = TextEditingController();
  final calcado = TextEditingController();
  final observacoes = TextEditingController();
  String tipo = 'Uniforme';
  bool enviando = false;

  final uniformes = const [
    'Calça de Elástico', 'Calça Portaria', 'Camisa Portaria', 'Camiseta Branca', 'Camiseta Cinza', 'Jaqueta', 'Avental'
  ];
  final limpeza = const [
    'Porta Sabonete Líquido Plast PET 1L Cristal', 'Álcool Perf. 2L', 'Mop Pó Acrílico 80x15cm', 'Copo Descartável 180 ml',
    'Pano Multiuso Rolo 28x25', 'Papel Higiênico Max Pure 30m LV 12 PG11', 'Saco de Lixo 80 L', 'Saco de Lixo 30 L',
    'Esponja Condor c/ Display LV4PG3', 'Toalha Interfolha Roma 100%', 'Multiuso 5 L Flotador', 'Purificador Puro Ar 250 ml Flor Yang',
    'Lustra Móveis Granel 500 ml', 'Saponáceo Produlimp 1 L'
  ];
  final epis = const ['Botina', 'Bota', 'Luva', 'Óculos de Proteção', 'Protetor Auricular', 'Capacete', 'Colete Refletivo', 'Cinto de Segurança'];

  List<String> get produtos => tipo == 'Uniforme' ? uniformes : tipo == 'Material de Limpeza' ? limpeza : tipo == 'EPI' ? epis : const [];

  Future<void> enviar() async {
    if (!keyForm.currentState!.validate()) return;
    setState(() => enviando = true);
    try {
      final r = await Api.request('POST', '/requisicoes', {
        'empresa': empresa.text.trim(), 'funcionario': funcionario.text.trim(), 'tipo': tipo,
        'produto': produto.text.trim(), 'quantidade': int.tryParse(quantidade.text) ?? 1,
        'tamanho': tamanho.text.trim(), 'calcado': calcado.text.trim(), 'observacoes': observacoes.text.trim(),
        'solicitante': widget.user['nome'], 'usuario': widget.user['usuario'],
      });
      if (!mounted) return;
      await showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Requisição enviada'),
        content: Text('Nº ${r['numero']}\n\nAguarde a disponibilidade para retirada.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ));
      empresa.clear(); funcionario.clear(); produto.clear(); tamanho.clear(); calcado.clear(); observacoes.clear(); quantidade.text = '1';
      widget.recarregar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally { if (mounted) setState(() => enviando = false); }
  }

  Widget campo(TextEditingController c, String label, {bool obrigatorio = false, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c, keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: obrigatorio ? (v) => v == null || v.trim().isEmpty ? 'Informe este campo' : null : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: keyForm,
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Text('NOVA REQUISIÇÃO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(height: 16),
          campo(empresa, 'Empresa / Condomínio', obrigatorio: true),
          campo(funcionario, 'Funcionário', obrigatorio: true),
          DropdownButtonFormField<String>(
            value: tipo,
            decoration: const InputDecoration(labelText: 'Tipo de solicitação', border: OutlineInputBorder()),
            items: ['Uniforme', 'EPI', 'Material de Limpeza', 'Material'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
            onChanged: (x) => setState(() { tipo = x!; produto.clear(); }),
          ),
          const SizedBox(height: 12),
          if (produtos.isEmpty) campo(produto, 'Produto solicitado', obrigatorio: true) else DropdownButtonFormField<String>(
            value: produto.text.isEmpty ? null : produto.text,
            decoration: const InputDecoration(labelText: 'Produto solicitado', border: OutlineInputBorder()),
            items: produtos.map((x) => DropdownMenuItem(value: x, child: Text(x, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (x) => setState(() => produto.text = x ?? ''),
            validator: (v) => v == null || v.isEmpty ? 'Selecione o produto' : null,
          ),
          const SizedBox(height: 12),
          campo(quantidade, 'Quantidade', obrigatorio: true, keyboard: TextInputType.number),
          campo(tamanho, 'Tamanho do uniforme'),
          campo(calcado, 'Numeração do calçado'),
          campo(observacoes, 'Observações'),
          Align(alignment: Alignment.centerLeft, child: Text('Supervisor/Inspetora: ${widget.user['nome']}')),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: enviando ? null : enviar, icon: const Icon(Icons.send), label: Text(enviando ? 'ENVIANDO...' : 'ENVIAR REQUISIÇÃO'))),
        ]),
      ),
    );
  }
}

class AdminPage extends StatelessWidget {
  final List<dynamic> requisicoes;
  final VoidCallback recarregar;
  const AdminPage({super.key, required this.requisicoes, required this.recarregar});

  Future<void> alterar(BuildContext context, String id, String status) async {
    await Api.request('PATCH', '/requisicoes/$id', {'status': status});
    recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('REQUISIÇÕES RECEBIDAS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (requisicoes.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nenhuma requisição recebida.'))),
        ...requisicoes.map((r) => Card(child: ListTile(
          leading: Icon(Icons.inventory_2, color: _corStatus(r['status']?.toString() ?? 'Pendente')),
          title: Text('${r['numero']} • ${r['empresa']}'),
          subtitle: Text('${r['funcionario']} • ${r['tipo']} • ${r['produto']} x${r['quantidade']}\n${r['status']}'),
          onTap: () => _detalhe(context, r),
        ))),
      ],
    );
  }

  Future<void> _detalhe(BuildContext context, dynamic r) async {
    final status = r['status']?.toString() ?? '';
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('Requisição ${r['numero']}'),
      content: SingleChildScrollView(child: Text('Empresa: ${r['empresa']}\nFuncionário: ${r['funcionario']}\nProduto: ${r['produto']}\nTamanho: ${r['tamanho'] ?? ''}\nCalçado: ${r['calcado'] ?? ''}\nQuantidade: ${r['quantidade']}\nResponsável: ${r['solicitante']}\nObservações: ${r['observacoes'] ?? ''}\n\nStatus: $status')),
      actions: [
        if (status == 'Pendente') TextButton(onPressed: () { Navigator.pop(context); alterar(context, r['id'].toString(), 'Separando'); }, child: const Text('INICIAR SEPARAÇÃO')),
        if (status == 'Separando') TextButton(onPressed: () { Navigator.pop(context); alterar(context, r['id'].toString(), 'Disponível para Entrega'); }, child: const Text('DISPONÍVEL PARA ENTREGA')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('FECHAR')),
      ],
    ));
  }
}

Color _corStatus(String s) {
  if (s == 'Entregue') return Colors.green;
  if (s == 'Disponível para Entrega') return Colors.blue;
  if (s == 'Separando') return Colors.orange;
  return Colors.red;
}

class Historico extends StatelessWidget {
  final List<dynamic> requisicoes;
  final bool admin;
  final VoidCallback recarregar;
  const Historico({super.key, required this.requisicoes, required this.admin, required this.recarregar});

  Future<void> entregar(BuildContext context, dynamic r) async {
    final assinatura = await showDialog<String>(context: context, builder: (_) => SignatureDialog());
    if (assinatura == null || assinatura.isEmpty) return;
    try {
      await Api.request('PATCH', '/requisicoes/${r['id']}/entrega', {
        'recebedor': r['funcionario'],
        'assinatura': assinatura,
      });
      recarregar();
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recebimento confirmado e assinatura registrada.')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('HISTÓRICO / REQUISIÇÕES', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (requisicoes.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nenhuma requisição encontrada.'))),
        ...requisicoes.map((r) {
          final disponivel = r['status'] == 'Disponível para Entrega';
          return Card(child: ListTile(
            leading: Icon(Icons.receipt_long, color: _corStatus(r['status']?.toString() ?? 'Pendente')),
            title: Text('${r['numero']} - ${r['produto']}'),
            subtitle: Text('${r['empresa']} | ${r['funcionario']}\nQtd.: ${r['quantidade']} | Status: ${r['status']}\nSolicitado por: ${r['solicitante']}'),
            trailing: disponivel && !admin ? FilledButton(onPressed: () => entregar(context, r), child: const Text('RETIRAR')) : null,
          ));
        }),
      ],
    );
  }
}

class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key});
  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final pontos = <Offset>[];
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('COMPROVANTE DE ENTREGA'),
      content: SizedBox(
        width: 500,
        height: 280,
        child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Colete a assinatura do funcionário para confirmar o recebimento.')),
          const SizedBox(height: 12),
          Expanded(child: Container(
            decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(8)),
            child: GestureDetector(
              onPanStart: (d) => setState(() => pontos.add(d.localPosition)),
              onPanUpdate: (d) => setState(() => pontos.add(d.localPosition)),
              onPanEnd: (_) => setState(() => pontos.add(Offset.infinite)),
              child: CustomPaint(painter: SignaturePainter(pontos), child: const SizedBox.expand()),
            ),
          )),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => setState(pontos.clear), child: const Text('LIMPAR')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
        FilledButton(onPressed: pontos.where((p) => p != Offset.infinite).isEmpty ? null : () => Navigator.pop(context, _serialize()), child: const Text('CONFIRMAR RECEBIMENTO')),
      ],
    );
  }

  String _serialize() => jsonEncode(pontos.map((p) => p == Offset.infinite ? null : {'x': p.dx, 'y': p.dy}).toList());
}

class SignaturePainter extends CustomPainter {
  final List<Offset> points;
  SignaturePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      if (a == Offset.infinite || b == Offset.infinite) continue;
      canvas.drawLine(a, b, paint);
    }
  }
  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => oldDelegate.points != points;
}
