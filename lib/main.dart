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

  static Future<Map<String, dynamic>> request(String method, String path, [Map<String, dynamic>? data]) async {
    final url = Uri.parse('${await base()}$path');
    final headers = {'Content-Type': 'application/json'};
    late http.Response r;
    if (method == 'GET') {
      r = await http.get(url);
    } else if (method == 'POST') {
      r = await http.post(url, headers: headers, body: jsonEncode(data ?? {}));
    } else {
      r = await http.patch(url, headers: headers, body: jsonEncode(data ?? {}));
    }
    if (r.statusCode >= 400) throw Exception(r.body);
    return r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getList(String path) async {
    final r = await http.get(Uri.parse('${await base()}$path'));
    if (r.statusCode >= 400) throw Exception(r.body);
    return jsonDecode(r.body) as List<dynamic>;
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
  bool carregando = false;
  String? erro;

  Future<void> entrar() async {
    setState(() => carregando = true);
    try {
      final user = await Api.request('POST', '/login', {'usuario': usuario.text.trim(), 'senha': senha.text});
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.inventory_2, size: 72),
              const SizedBox(height: 12),
              const Text('A Liga Almoxarifado', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 28),
              TextField(controller: usuario, decoration: const InputDecoration(labelText: 'Usuário', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: senha, obscureText: true, decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder())),
              if (erro != null) Padding(padding: const EdgeInsets.all(10), child: Text(erro!, style: const TextStyle(color: Colors.red))),
              SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: carregando ? null : entrar, child: Text(carregando ? 'Entrando...' : 'ENTRAR'))),
            ]),
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

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    try {
      requisicoes = await Api.getList('/requisicoes?usuario=${Uri.encodeComponent(widget.user['usuario']?.toString() ?? '')}');
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.user['perfil'] == 'almoxarifado';
    return Scaffold(
      appBar: AppBar(title: Text(admin ? 'Painel do Almoxarifado' : 'A Liga Almoxarifado')),
      body: aba == 0
          ? (admin ? AdminPage(requisicoes: requisicoes, recarregar: carregar) : NovaRequisicao(user: widget.user, recarregar: carregar))
          : Historico(requisicoes: requisicoes),
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
  final formKey = GlobalKey<FormState>();
  final empresa = TextEditingController();
  final funcionario = TextEditingController();
  final produto = TextEditingController();
  final quantidade = TextEditingController(text: '1');
  final tamanho = TextEditingController();
  final calcado = TextEditingController();
  final observacoes = TextEditingController();
  String tipo = 'Uniforme';

  Future<void> enviar() async {
    if (!formKey.currentState!.validate()) return;
    try {
      final r = await Api.request('POST', '/requisicoes', {
        'empresa': empresa.text.trim(),
        'funcionario': funcionario.text.trim(),
        'tipo': tipo,
        'produto': produto.text.trim(),
        'quantidade': int.tryParse(quantidade.text) ?? 1,
        'tamanho': tamanho.text.trim(),
        'calcado': calcado.text.trim(),
        'observacoes': observacoes.text.trim(),
        'solicitante': widget.user['nome'],
        'usuario': widget.user['usuario'],
      });
      if (!mounted) return;
      await showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Requisição enviada com sucesso'),
        content: Text('Nº da requisição: ${r['numero']}\nAguarde a disponibilidade para retirada.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ));
      widget.recarregar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget campo(TextEditingController c, String label, {bool obrigatorio = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(controller: c, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), validator: obrigatorio ? (v) => v == null || v.trim().isEmpty ? 'Informe este campo' : null : null),
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(key: formKey, child: Column(children: [
        const Align(alignment: Alignment.centerLeft, child: Text('NOVA REQUISIÇÃO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        campo(empresa, 'Empresa / Condomínio', obrigatorio: true),
        campo(funcionario, 'Funcionário', obrigatorio: true),
        DropdownButtonFormField<String>(value: tipo, decoration: const InputDecoration(labelText: 'Tipo de solicitação', border: OutlineInputBorder()), items: ['Uniforme', 'EPI', 'Material de Limpeza', 'Material'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (x) => setState(() => tipo = x!)),
        const SizedBox(height: 12),
        campo(produto, 'Produto solicitado', obrigatorio: true),
        campo(quantidade, 'Quantidade', obrigatorio: true),
        campo(tamanho, 'Tamanho do uniforme'),
        campo(calcado, 'Numeração do calçado'),
        campo(observacoes, 'Observações'),
        Align(alignment: Alignment.centerLeft, child: Text('Supervisor/Inspetora: ${widget.user['nome']}')),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: enviar, icon: const Icon(Icons.send), label: const Text('ENVIAR REQUISIÇÃO'))),
      ])),
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
    return ListView(padding: const EdgeInsets.all(12), children: [
      const Text('REQUISIÇÕES RECEBIDAS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...requisicoes.map((r) => Card(child: ListTile(
        leading: Icon(Icons.inventory_2, color: r['status'] == 'Entregue' ? Colors.green : r['status'] == 'Separando' ? Colors.orange : Colors.red),
        title: Text('${r['numero']} • ${r['empresa']}'),
        subtitle: Text('${r['funcionario']} • ${r['tipo']} • ${r['produto']} x${r['quantidade']}\n${r['status']}'),
        onTap: () => showDialog(context: context, builder: (_) => AlertDialog(
          title: Text('Requisição ${r['numero']}'),
          content: Text('Empresa: ${r['empresa']}\nFuncionário: ${r['funcionario']}\nProduto: ${r['produto']}\nTamanho: ${r['tamanho'] ?? ''}\nQuantidade: ${r['quantidade']}\nResponsável: ${r['solicitante']}'),
          actions: [
            if (r['status'] == 'Pendente') TextButton(onPressed: () { Navigator.pop(context); alterar(context, r['id'].toString(), 'Separando'); }, child: const Text('SEPARAR')),
            if (r['status'] == 'Separando') TextButton(onPressed: () { Navigator.pop(context); alterar(context, r['id'].toString(), 'Disponível para Entrega'); }, child: const Text('DISPONÍVEL')),
          ],
        )),
      )))
    ]);
  }
}

class Historico extends StatelessWidget {
  final List<dynamic> requisicoes;
  const Historico({super.key, required this.requisicoes});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: requisicoes.map((r) => Card(child: ListTile(title: Text('${r['numero']} - ${r['produto']}'), subtitle: Text('${r['empresa']} | ${r['funcionario']}\nStatus: ${r['status']}')))).toList());
}
