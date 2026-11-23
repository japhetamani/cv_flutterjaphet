import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// Si vous utilisez l'émulateur Android : 'http://10.0.2.2/api-test/public'
// Si vous utilisez Chrome (Web) ou un vrai téléphone : 'http://localhost/api-test/public'
const String kBaseUrl = 'http://localhost/api-test/public';

// ============================================================================
// MODÈLE
// ============================================================================
class Membre {
  final int? id;
  final String nom;
  final String postnom;
  final String prenom;
  final String lieuNaissance;
  final String dateNaissance;
  final String parente;
  final String? imageUrl;

  Membre({
    this.id,
    required this.nom,
    required this.postnom,
    required this.prenom,
    required this.lieuNaissance,
    required this.dateNaissance,
    required this.parente,
    this.imageUrl,
  });

  factory Membre.fromJson(Map<String, dynamic> json) {
    return Membre(
      id: json['id'],
      nom: json['nom'] ?? '',
      postnom: json['postnom'] ?? '',
      prenom: json['prenom'] ?? '',
      lieuNaissance: json['lieu_naissance'] ?? '',
      dateNaissance: json['date_naissance'] ?? '',
      parente: json['parente'] ?? '',
      imageUrl: json['image_url'],
    );
  }

  // Utilisation de String au lieu de dynamic pour éviter les erreurs de type
  Map<String, String> toJson() {
    return {
      'nom': nom,
      'postnom': postnom,
      'prenom': prenom,
      'lieu_naissance': lieuNaissance,
      'date_naissance': dateNaissance,
      'parente': parente,
    };
  }
}

class ApiService {
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('$kBaseUrl/accounts/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Erreur de connexion');
  }

  static Future<List<Membre>> getMembres() async {
    final res = await http.get(
      Uri.parse('$kBaseUrl/famille-membres'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final list = data['data'] as List;
      return list.map((e) => Membre.fromJson(e)).toList();
    }
    throw Exception('Erreur lors du chargement');
  }

  // Fonction utilitaire pour lire les erreurs JSON de l'API
  static String _parseError(http.Response res) {
    try {
      final data = jsonDecode(res.body);
      if (data['errors'] != null) {
        return (data['errors'] as Map).values.first
            .toString(); // Prend la 1ère erreur
      }
      return data['message'] ?? 'Erreur inconnue';
    } catch (_) {
      return 'Erreur serveur (${res.statusCode})';
    }
  }

  static Future<void> addMembre(Membre m, {File? image}) async {
    try {
      if (image != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$kBaseUrl/famille-membres'),
        );
        request.headers.addAll({'Accept': 'application/json'});
        request.fields.addAll(m.toJson());
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );

        final response = await request.send();
        final res = await http.Response.fromStream(response);
        if (res.statusCode != 201) throw Exception(_parseError(res));
      } else {
        final res = await http.post(
          Uri.parse('$kBaseUrl/famille-membres'),
          headers: _headers,
          body: jsonEncode(m.toJson()),
        );
        if (res.statusCode != 201) throw Exception(_parseError(res));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<void> updateMembre(Membre m, {File? image}) async {
    try {
      if (image != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$kBaseUrl/famille-membres/${m.id}'),
        );
        request.headers.addAll({'Accept': 'application/json'});
        request.fields.addAll(m.toJson());
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );

        final response = await request.send();
        final res = await http.Response.fromStream(response);
        if (res.statusCode != 200) throw Exception(_parseError(res));
      } else {
        final res = await http.put(
          Uri.parse('$kBaseUrl/famille-membres/${m.id}'),
          headers: _headers,
          body: jsonEncode(m.toJson()),
        );
        if (res.statusCode != 200) throw Exception(_parseError(res));
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  static Future<void> deleteMembre(int id) async {
    final res = await http.delete(
      Uri.parse('$kBaseUrl/famille-membres/$id'),
      headers: _headers,
    );
    if (res.statusCode != 200) throw Exception('Erreur lors de la suppression');
  }
}

// ============================================================================
// APP
// ============================================================================
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CV Japhet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: const LoginPage(),
    );
  }
}

// ============================================================================
// LOGIN
// ============================================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.login(_emailCtrl.text.trim(), _passCtrl.text);
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.school_rounded,
                  size: 80,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bienvenue sur le CV de Japhet',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Se connecter',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN SHELL (Navigation)
// ============================================================================
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _pages = const [AccueilPage(), FamillePage(), ContactPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Mon CV',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Famille',
          ),
          NavigationDestination(
            icon: Icon(Icons.contact_mail_outlined),
            label: 'Contact',
          ),
        ],
      ),
    );
  }
}

class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Remplacez cette ligne :
            // const CircleAvatar(radius: 50, backgroundColor: Color(0xFFE8F5E9), child: Text('JK', style: TextStyle(fontSize: 30, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold))),

            // Par ce bloc :
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/japhet.jpg',
                  width: 110,
                  height: 110,
                  fit: BoxFit.cover,
                  // Si l'image n'est pas trouvée, on affiche un fallback avec les initiales
                  errorBuilder: (_, __, ___) => Container(
                    width: 110,
                    height: 110,
                    color: const Color(0xFFE8F5E9),
                    child: const Center(
                      child: Text(
                        'JK',
                        style: TextStyle(
                          fontSize: 30,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Kambale Amani Japhet',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Coach d\'anglais | Formateur',
              style: GoogleFonts.poppins(color: Colors.grey[700]),
            ),
            const SizedBox(height: 32),
            _buildCard(
              'Profil',
              'Coach d\'anglais motivé et passionné par l\'enseignement des langues.',
            ),
            _buildCard('Expérience', 'Coach d\'anglais / Enseignant à Lincs.'),
            _buildCard('Formation', 'ISIG Goma - Informatique (Diplômé)'),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(content, style: GoogleFonts.poppins(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Contact',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.phone, color: Color(0xFF2E7D32)),
            title: const Text('Téléphone'),
            subtitle: const Text('+243 980745421'),
            onTap: () => launchUrl(Uri.parse('tel:+243980745421')),
          ),
          ListTile(
            leading: const Icon(Icons.email, color: Color(0xFF2E7D32)),
            title: const Text('E-mail'),
            subtitle: const Text('japhetlusenge26@gmail.com'),
            onTap: () =>
                launchUrl(Uri.parse('mailto:japhetlusenge26@gmail.com')),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FAMILLE (CRUD avec DatePicker et belles cartes)
// ============================================================================
class FamillePage extends StatefulWidget {
  const FamillePage({super.key});
  @override
  State<FamillePage> createState() => _FamillePageState();
}

class _FamillePageState extends State<FamillePage> {
  List<Membre> _membres = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _membres = await ApiService.getMembres();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- FORMULAIRE DANS UN BOTTOM SHEET ---
  void _showForm({Membre? membre}) {
    final nomCtrl = TextEditingController(text: membre?.nom ?? '');
    final postnomCtrl = TextEditingController(text: membre?.postnom ?? '');
    final prenomCtrl = TextEditingController(text: membre?.prenom ?? '');
    final lieuCtrl = TextEditingController(text: membre?.lieuNaissance ?? '');
    final dateCtrl = TextEditingController(text: membre?.dateNaissance ?? '');
    final parenteCtrl = TextEditingController(text: membre?.parente ?? '');
    File? image;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permet de prendre toute la hauteur nécessaire
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      membre == null
                          ? 'Ajouter un membre'
                          : 'Modifier le membre',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField('Nom', nomCtrl, required: true),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            'Postnom',
                            postnomCtrl,
                            required: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField('Prénom', prenomCtrl, required: true),
                    const SizedBox(height: 12),
                    _buildField('Lieu de naissance', lieuCtrl, required: true),
                    const SizedBox(height: 12),

                    // SÉLECTEUR DE DATE
                    TextFormField(
                      controller: dateCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Date de naissance',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            // Format requis par l'API : AAAA-MM-JJ
                            dateCtrl.text = DateFormat('yyyy-MM-dd')
                                .format(picked);
                          });
                        }
                      },
                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      'Lien de parenté (ex: Père)',
                      parenteCtrl,
                      required: true,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (picked != null)
                          setSheetState(() => image = File(picked.path));
                      },
                      icon: const Icon(Icons.image),
                      label: Text(
                        image == null
                            ? 'Choisir une photo (Optionnel)'
                            : 'Photo sélectionnée',
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          final m = Membre(
                            id: membre?.id,
                            nom: nomCtrl.text,
                            postnom: postnomCtrl.text,
                            prenom: prenomCtrl.text,
                            lieuNaissance: lieuCtrl.text,
                            dateNaissance: dateCtrl.text,
                            parente: parenteCtrl.text,
                          );

                          try {
                            if (membre == null) {
                              await ApiService.addMembre(m, image: image);
                            } else {
                              await ApiService.updateMembre(m, image: image);
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          } catch (e) {
                            if (ctx.mounted)
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Erreur: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                          }
                        },
                        child: const Text('Enregistrer'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool required = false,
  }) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) => (required && v!.isEmpty) ? 'Requis' : null,
    );
  }

  // --- AFFICHAGE DE LA LISTE ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Famille'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _membres.isEmpty
          ? Center(
              child: Text(
                'Aucun membre pour le moment.',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _membres.length,
              itemBuilder: (context, i) {
                final m = _membres[i];
                return Card(
                  elevation: 2,
                  shadowColor: Colors.black12,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Hero(
                          tag: 'avatar_${m.id}',
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: m.imageUrl != null
                                ? NetworkImage(m.imageUrl!)
                                : null,
                            child: m.imageUrl == null
                                ? const Icon(Icons.person, color: Colors.grey)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.nom} ${m.postnom} ${m.prenom}',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${m.parente} • ${m.lieuNaissance}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Né(e) le: ${m.dateNaissance}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              _showForm(membre: m);
                            } else if (value == 'delete') {
                              try {
                                await ApiService.deleteMembre(m.id!);
                                _load();
                              } catch (e) {
                                if (context.mounted)
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text('$e')));
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Modifier'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Supprimer',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
