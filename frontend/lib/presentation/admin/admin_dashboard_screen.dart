import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/datasources/admin/admin_service.dart';
import '../providers/user_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  AdminDashboardScreenState createState() => AdminDashboardScreenState();
}

class AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  late Future<List<Map<String, dynamic>>> _fetchUsersFuture;
  late Future<List<Map<String, dynamic>>> _fetchSongsFuture;
  late Future<List<Map<String, dynamic>>> _fetchFeaturedSongsFuture;
  late Future<Map<String, dynamic>> _fetchOverviewDataFuture;
  final AdminService _adminService = AdminService();
  bool _isInitialized = false;
  String _userSearchQuery = '';
  String _songSearchQuery = '';
  String _featuredSongSearchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeFutures();
      _isInitialized = true;
    }
  }

  void _initializeFutures() {
    final token = ref.read(userProvider).token ?? '';
    print('Initializing futures with token: $token');
    _fetchUsersFuture = _adminService.fetchAllUsers(token);
    _fetchSongsFuture = _adminService.fetchAllSongs(token);
    _fetchFeaturedSongsFuture = _adminService.fetchFeaturedSongs(token);
    _fetchOverviewDataFuture = _fetchOverviewData(token);
  }

  Future<Map<String, dynamic>> _fetchOverviewData(String token) async {
    final users = await _fetchUsersFuture;
    final songs = await _fetchSongsFuture;
    final featuredSongs = await _fetchFeaturedSongsFuture;
    final artists = users.where((user) => user['role'] == 'artist').toList();
    final totalListeners = await _adminService.fetchTotalListeners(token);
    return {
      'totalUsers': users.length,
      'totalSongs': songs.length,
      'totalArtists': artists.length,
      'totalListeners': totalListeners,
      'totalFeaturedSongs': featuredSongs.length,
    };
  }

  Future<void> _deleteUser(String userId) async {
    final token = ref.read(userProvider).token ?? '';
    try {
      await _adminService.deleteUser(token, userId);
      setState(() {
        _fetchUsersFuture = _adminService.fetchAllUsers(token);
        _fetchOverviewDataFuture = _fetchOverviewData(token);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete user: $e')),
      );
    }
  }

  Future<void> _deleteSong(String songId) async {
    final token = ref.read(userProvider).token ?? '';
    try {
      await _adminService.deleteSong(token, songId);
      setState(() {
        _fetchSongsFuture = _adminService.fetchAllSongs(token);
        _fetchFeaturedSongsFuture = _adminService.fetchFeaturedSongs(token);
        _fetchOverviewDataFuture = _fetchOverviewData(token);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete song: $e')),
      );
    }
  }

  Future<void> _pinFeaturedSong(String songId, bool isFeatured) async {
    final token = ref.read(userProvider).token ?? '';
    try {
      if (isFeatured) {
        await _adminService.unpinFeaturedSong(token, songId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Song unpinned from featured')),
        );
      } else {
        final formKey = GlobalKey<FormState>();
        String featuredOrder = '0';

        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF212121),
            title: const Text('Pin as Featured', style: TextStyle(color: Colors.white)),
            content: Form(
              key: formKey,
              child: TextFormField(
                initialValue: featuredOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Featured Order',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (value) => value!.isEmpty ? 'Enter a valid number' : null,
                onSaved: (value) => featuredOrder = value!,
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                child: const Text('Pin', style: TextStyle(color: Color(0xFF1DB954))),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    formKey.currentState!.save();
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            ],
          ),
        );

        if (confirm == true) {
          await _adminService.pinFeaturedSong(token, songId, int.parse(featuredOrder));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Song pinned as featured')),
          );
        }
      }
      setState(() {
        _fetchSongsFuture = _adminService.fetchAllSongs(token);
        _fetchFeaturedSongsFuture = _adminService.fetchFeaturedSongs(token);
        _fetchOverviewDataFuture = _fetchOverviewData(token);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update featured status: $e')),
      );
    }
  }

  Future<void> _addUser(String fullName, String email, String role, String password) async {
    final token = ref.read(userProvider).token ?? '';
    try {
      await _adminService.createUser(token, fullName, email, role, password);
      setState(() {
        _fetchUsersFuture = _adminService.fetchAllUsers(token);
        _fetchOverviewDataFuture = _fetchOverviewData(token);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add user: $e')),
      );
    }
  }

  Future<void> _updateUser(String userId, String fullName, String email, String role) async {
    final token = ref.read(userProvider).token ?? '';
    try {
      await _adminService.updateUser(token, userId, fullName, email, role);
      setState(() {
        _fetchUsersFuture = _adminService.fetchAllUsers(token);
        _fetchOverviewDataFuture = _fetchOverviewData(token);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user: $e')),
      );
    }
  }

  Future<void> _addSong(String title, String genre, String description, String artistId, String audioPath, String coverImagePath) async {
    final token = ref.read(userProvider).token ?? '';
    try {
      await _adminService.createSong(token, title, genre, description, artistId, audioPath, coverImagePath);
      setState(() {
        _fetchSongsFuture = _adminService.fetchAllSongs(token);
        _fetchFeaturedSongsFuture = _adminService.fetchFeaturedSongs(token);
        _fetchOverviewDataFuture = _fetchOverviewData(token);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song added successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add song: $e')),
      );
    }
  }

  Future<void> _updateSong(String songId, String title, String genre) async {
    final token = ref.read(userProvider).token ?? '';
    try {
      await _adminService.updateSong(token, songId, title, genre);
      setState(() {
        _fetchSongsFuture = _adminService.fetchAllSongs(token);
        _fetchFeaturedSongsFuture = _adminService.fetchFeaturedSongs(token);
        _fetchOverviewDataFuture = _fetchOverviewData(token);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update song: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final userState = ref.watch(userProvider);
        final userRole = userState.role?.toLowerCase();
        print('Current user role in dashboard: $userRole');

        if (userRole != 'admin') {
          return Scaffold(
            backgroundColor: const Color(0xFF000000),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Access Denied: Admins Only',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      context.pop();
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            backgroundColor: const Color(0xFF000000),
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  context.pop();
                },
              ),
              title: Text(
                'Admin Dashboard',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
              elevation: Theme.of(context).appBarTheme.elevation,
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Users'),
                  Tab(text: 'Songs'),
                  Tab(text: 'Featured Songs'),
                ],
                indicatorColor: Color(0xFF1DB954),
                labelColor: Color(0xFF1DB954),
                unselectedLabelColor: Colors.white54,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.white),
                  onPressed: () => _showAddUserDialog(context),
                  tooltip: 'Add User',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () => _showEditUserDialog(context, null),
                  tooltip: 'Edit User',
                ),
                IconButton(
                  icon: const Icon(Icons.music_note, color: Colors.white),
                  onPressed: () => _showAddSongDialog(context),
                  tooltip: 'Add Song',
                ),
                IconButton(
                  icon: const Icon(Icons.star, color: Colors.white),
                  onPressed: () {
                    context.push('/manage-featured-content');
                  },
                  tooltip: 'Manage Featured Content',
                ),
              ],
            ),
            body: TabBarView(
              children: [
                // Overview Tab
                FutureBuilder<Map<String, dynamic>>(
                  future: _fetchOverviewDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading overview: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    } else if (!snapshot.hasData) {
                      return const Center(
                        child: Text(
                          'No data available.',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final data = snapshot.data!;
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildOverviewCard('Total Users', data['totalUsers'].toString()),
                              _buildOverviewCard('Total Songs', data['totalSongs'].toString()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildOverviewCard('Total Artists', data['totalArtists'].toString()),
                              _buildOverviewCard('Total Listeners', data['totalListeners'].toString()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildOverviewCard('Featured Songs', data['totalFeaturedSongs'].toString()),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Users Tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search Users',
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          setState(() {
                            _userSearchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return FutureBuilder<List<Map<String, dynamic>>>(
                            future: _fetchUsersFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Error loading users: ${snapshot.error}',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      const SizedBox(height: 10),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            final token = ref.read(userProvider).token ?? '';
                                            _fetchUsersFuture = _adminService.fetchAllUsers(token);
                                          });
                                        },
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No users found.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              final users = snapshot.data!.where((user) {
                                final fullName = user['fullName']?.toString().toLowerCase() ?? '';
                                final email = user['email']?.toString().toLowerCase() ?? '';
                                final role = user['role']?.toString().toLowerCase() ?? '';
                                return fullName.contains(_userSearchQuery) ||
                                    email.contains(_userSearchQuery) ||
                                    role.contains(_userSearchQuery);
                              }).toList();
                              return constraints.maxWidth < 600
                                  ? ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: users.length,
                                itemBuilder: (context, index) {
                                  final user = users[index];
                                  return Card(
                                    color: const Color(0xFF212121),
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: ListTile(
                                      title: Text(
                                        user['fullName'] ?? 'Unknown',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Email: ${user['email'] ?? 'N/A'}',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                          Text(
                                            'Role: ${user['role'] ?? 'N/A'}',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.yellow),
                                            onPressed: () => _showEditUserDialog(context, user),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteUser(user['_id']),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                                  : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Name', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Email', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Role', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Actions', style: TextStyle(color: Colors.white))),
                                  ],
                                  rows: users.map((user) {
                                    return DataRow(cells: [
                                      DataCell(Text(user['fullName'] ?? 'Unknown', style: const TextStyle(color: Colors.white))),
                                      DataCell(Text(user['email'] ?? 'N/A', style: const TextStyle(color: Colors.white))),
                                      DataCell(Text(user['role'] ?? 'N/A', style: const TextStyle(color: Colors.white))),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.yellow),
                                              onPressed: () => _showEditUserDialog(context, user),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteUser(user['_id']),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                  dataRowColor: WidgetStateProperty.all(const Color(0xFF212121)),
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1DB954)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Songs Tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search Songs',
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          setState(() {
                            _songSearchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return FutureBuilder<List<Map<String, dynamic>>>(
                            future: _fetchSongsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Error loading songs: ${snapshot.error}',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      const SizedBox(height: 10),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            final token = ref.read(userProvider).token ?? '';
                                            _fetchSongsFuture = _adminService.fetchAllSongs(token);
                                          });
                                        },
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No songs found.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              final songs = snapshot.data!.where((song) {
                                final title = song['title']?.toString().toLowerCase() ?? '';
                                final artistName = song['artistName']?.toString().toLowerCase() ?? '';
                                final genre = song['genre']?.toString().toLowerCase() ?? '';
                                return title.contains(_songSearchQuery) ||
                                    artistName.contains(_songSearchQuery) ||
                                    genre.contains(_songSearchQuery);
                              }).toList();
                              return constraints.maxWidth < 600
                                  ? ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: songs.length,
                                itemBuilder: (context, index) {
                                  final song = songs[index];
                                  return Card(
                                    color: const Color(0xFF212121),
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: ListTile(
                                      leading: song['coverImagePath'] != null
                                          ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          song['coverImagePath'],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.white70,
                                            size: 50,
                                          ),
                                        ),
                                      )
                                          : const Icon(Icons.music_note, color: Colors.white70, size: 50),
                                      title: Text(
                                        song['title'] ?? 'Unknown',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Artist: ${song['artistName'] ?? 'N/A'}',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                          Text(
                                            'Genre: ${song['genre'] ?? 'N/A'}',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              song['isFeatured'] == true ? Icons.star : Icons.star_border,
                                              color: song['isFeatured'] == true
                                                  ? const Color(0xFF1DB954)
                                                  : Colors.white70,
                                            ),
                                            onPressed: () => _pinFeaturedSong(song['_id'], song['isFeatured'] ?? false),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit, color: Colors.yellow),
                                            onPressed: () => _showEditSongDialog(context, song),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteSong(song['_id']),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                                  : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Cover', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Title', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Artist Name', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Genre', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Featured', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Actions', style: TextStyle(color: Colors.white))),
                                  ],
                                  rows: songs.map((song) {
                                    return DataRow(cells: [
                                      DataCell(
                                        song['coverImagePath'] != null
                                            ? Image.network(
                                          song['coverImagePath'],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.white70,
                                            size: 50,
                                          ),
                                        )
                                            : const Icon(Icons.music_note, color: Colors.white70, size: 50),
                                      ),
                                      DataCell(Text(song['title'] ?? 'Unknown', style: const TextStyle(color: Colors.white))),
                                      DataCell(Text(song['artistName'] ?? 'N/A', style: const TextStyle(color: Colors.white))),
                                      DataCell(Text(song['genre'] ?? 'N/A', style: const TextStyle(color: Colors.white))),
                                      DataCell(
                                        IconButton(
                                          icon: Icon(
                                            song['isFeatured'] == true ? Icons.star : Icons.star_border,
                                            color: song['isFeatured'] == true
                                                ? const Color(0xFF1DB954)
                                                : Colors.white70,
                                          ),
                                          onPressed: () => _pinFeaturedSong(song['_id'], song['isFeatured'] ?? false),
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.yellow),
                                              onPressed: () => _showEditSongDialog(context, song),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteSong(song['_id']),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                  dataRowColor: WidgetStateProperty.all(const Color(0xFF212121)),
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1DB954)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Featured Songs Tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search Featured Songs',
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                          prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (value) {
                          setState(() {
                            _featuredSongSearchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return FutureBuilder<List<Map<String, dynamic>>>(
                            future: _fetchFeaturedSongsFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Error loading featured songs: ${snapshot.error}',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      const SizedBox(height: 10),
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            final token = ref.read(userProvider).token ?? '';
                                            _fetchFeaturedSongsFuture = _adminService.fetchFeaturedSongs(token);
                                          });
                                        },
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'No featured songs found.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                );
                              }

                              final songs = snapshot.data!.where((song) {
                                final title = song['title']?.toString().toLowerCase() ?? '';
                                final artistName = song['artistName']?.toString().toLowerCase() ?? '';
                                final genre = song['genre']?.toString().toLowerCase() ?? '';
                                return title.contains(_featuredSongSearchQuery) ||
                                    artistName.contains(_featuredSongSearchQuery) ||
                                    genre.contains(_featuredSongSearchQuery);
                              }).toList();
                              return constraints.maxWidth < 600
                                  ? ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: songs.length,
                                itemBuilder: (context, index) {
                                  final song = songs[index];
                                  return Card(
                                    color: const Color(0xFF212121),
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: ListTile(
                                      leading: song['coverImagePath'] != null
                                          ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          song['coverImagePath'],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.white70,
                                            size: 50,
                                          ),
                                        ),
                                      )
                                          : const Icon(Icons.music_note, color: Colors.white70, size: 50),
                                      title: Text(
                                        song['title'] ?? 'Unknown',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Artist: ${song['artistName'] ?? 'N/A'}',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                          Text(
                                            'Genre: ${song['genre'] ?? 'N/A'}',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                          Text(
                                            'Order: ${song['featuredOrder'] ?? '0'}',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.star, color: Color(0xFF1DB954)),
                                        onPressed: () => _pinFeaturedSong(song['_id'], true),
                                      ),
                                    ),
                                  );
                                },
                              )
                                  : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Cover', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Title', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Artist Name', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Genre', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Order', style: TextStyle(color: Colors.white))),
                                    DataColumn(label: Text('Actions', style: TextStyle(color: Colors.white))),
                                  ],
                                  rows: songs.map((song) {
                                    return DataRow(cells: [
                                      DataCell(
                                        song['coverImagePath'] != null
                                            ? Image.network(
                                          song['coverImagePath'],
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(
                                            Icons.image_not_supported,
                                            color: Colors.white70,
                                            size: 50,
                                          ),
                                        )
                                            : const Icon(Icons.music_note, color: Colors.white70, size: 50),
                                      ),
                                      DataCell(Text(song['title'] ?? 'Unknown', style: const TextStyle(color: Colors.white))),
                                      DataCell(Text(song['artistName'] ?? 'N/A', style: const TextStyle(color: Colors.white))),
                                      DataCell(Text(song['genre'] ?? 'N/A', style: const TextStyle(color: Colors.white))),
                                      DataCell(Text(song['featuredOrder']?.toString() ?? '0', style: const TextStyle(color: Colors.white))),
                                      DataCell(
                                        IconButton(
                                          icon: const Icon(Icons.star, color: Color(0xFF1DB954)),
                                          onPressed: () => _pinFeaturedSong(song['_id'], true),
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                  dataRowColor: WidgetStateProperty.all(const Color(0xFF212121)),
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFF1DB954)),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewCard(String title, String value) {
    return Expanded(
      child: Card(
        color: const Color(0xFF212121),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddUserDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String fullName = '';
    String email = '';
    String role = 'listener';
    String password = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF212121),
          title: const Text('Add New User', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? 'Enter full name' : null,
                  onSaved: (value) => fullName = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter valid email' : null,
                  onSaved: (value) => email = value!,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF212121),
                  items: ['listener', 'artist', 'admin'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    role = newValue!;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? 'Enter password' : null,
                  onSaved: (value) => password = value!,
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () => context.pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.black)),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  _addUser(fullName, email, role, password).then((_) {
                    context.pop();
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditUserDialog(BuildContext context, Map<String, dynamic>? user) {
    final formKey = GlobalKey<FormState>();
    String fullName = user?['fullName'] ?? '';
    String email = user?['email'] ?? '';
    String role = user?['role'] ?? 'listener';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF212121),
          title: const Text('Edit User', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: fullName,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? 'Enter full name' : null,
                  onSaved: (value) => fullName = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty || !value.contains('@') ? 'Enter valid email' : null,
                  onSaved: (value) => email = value!,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  dropdownColor: const Color(0xFF212121),
                  items: ['listener', 'artist', 'admin'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    role = newValue!;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () => context.pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.black)),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  _updateUser(user?['_id'], fullName, email, role).then((_) {
                    context.pop();
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddSongDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    String title = '';
    String genre = '';
    String description = '';
    String artistId = '';
    String audioPath = '';
    String coverImagePath = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF212121),
          title: const Text('Add New Song', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? 'Enter title' : null,
                  onSaved: (value) => title = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Genre',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? 'Enter genre' : null,
                  onSaved: (value) => genre = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSaved: (value) => description = value ?? '',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Artist ID',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? 'Enter artist ID' : null,
                  onSaved: (value) => artistId = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Audio Path',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? 'Enter audio path' : null,
                  onSaved: (value) => audioPath = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Cover Image Path',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSaved: (value) => coverImagePath = value ?? '',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () => context.pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.black)),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  _addSong(title, genre, description, artistId, audioPath, coverImagePath).then((_) {
                    context.pop();
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showEditSongDialog(BuildContext context, Map<String, dynamic>? song) {
    final formKey = GlobalKey<FormState>();
    String title = song?['title'] ?? '';
    String genre = song?['genre'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF212121),
          title: const Text('Edit Song', style: TextStyle(color: Colors.white)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: title,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? 'Enter title' : null,
                  onSaved: (value) => title = value!,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: genre,
                  decoration: const InputDecoration(
                    labelText: 'Genre',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1DB954))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) => value!.isEmpty ? 'Enter genre' : null,
                  onSaved: (value) => genre = value!,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () => context.pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.black)),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  _updateSong(song?['_id'], title, genre).then((_) {
                    context.pop();
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }
}