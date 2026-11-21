import 'package:flutter/material.dart';

import '../core/app_dependencies.dart';
import '../core/data/auth_repository.dart';
import '../core/models/advent.dart';
import '../core/models/surprise.dart';
import '../features/auth/sign_in_page.dart';
import '../features/calendar/calendar_page.dart';
import '../features/compose/compose_page.dart';
import '../features/gallery/gallery_page.dart';
import '../ui/riso.dart';
import '../ui/riso_theme.dart';

class AdventApp extends StatefulWidget {
  const AdventApp({super.key, this.dependencies});

  final AppDependencies? dependencies;

  @override
  State<AdventApp> createState() => _AdventAppState();
}

class _AdventAppState extends State<AdventApp> {
  late final Future<AppDependencies> _dependencies;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies == null
        ? AppDependencies.create()
        : Future.value(widget.dependencies);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Carl & Mariana Adventskalender',
      debugShowCheckedModeBanner: false,
      theme: risoTheme(),
      home: FutureBuilder<AppDependencies>(
        future: _dependencies,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(text: '${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return _AuthGate(dependencies: snapshot.data!);
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.actions = const []});

  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(spacing: 8, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final auth = dependencies.auth;
    return StreamBuilder<bool>(
      stream: auth.signedInChanges,
      initialData: auth.isSignedIn,
      builder: (context, snapshot) {
        if (snapshot.data != true) {
          return SignInPage(auth: auth, hint: dependencies.signInHint);
        }
        return _CoupleLoader(dependencies: dependencies);
      },
    );
  }
}

class _CoupleLoader extends StatefulWidget {
  const _CoupleLoader({required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<_CoupleLoader> createState() => _CoupleLoaderState();
}

class _CoupleLoaderState extends State<_CoupleLoader> {
  late Future<Couple> _couple;

  @override
  void initState() {
    super.initState();
    _couple = widget.dependencies.auth.loadCouple();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Couple>(
      future: _couple,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return _Message(
            text: error is AppFailure ? error.message : '$error',
            actions: [
              OutlinedButton(
                onPressed: () => setState(() {
                  _couple = widget.dependencies.auth.loadCouple();
                }),
                child: const Text('Try again'),
              ),
              TextButton(
                onPressed: widget.dependencies.auth.signOut,
                child: const Text('Sign out'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _HomeShell(
          dependencies: widget.dependencies,
          couple: snapshot.data!,
        );
      },
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({required this.dependencies, required this.couple});

  final AppDependencies dependencies;
  final Couple couple;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  /// Bumped to reload all pages (door opened, app resumed, test date changed).
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.dependencies.clock.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.dependencies.clock.removeListener(_onChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A new door may have opened or been filled while the app was away.
    if (state == AppLifecycleState.resumed) {
      _onChanged();
    }
  }

  void _onChanged() {
    if (mounted) {
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final couple = widget.couple;
    final titles = [
      'My tree',
      "${couple.partner.displayName}'s tree",
      'Gallery',
    ];
    final testDate = widget.dependencies.clock.testDate;
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        bottom: testDate == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(30),
                child: Container(
                  height: 30,
                  width: double.infinity,
                  color: Riso.yellow,
                  alignment: Alignment.center,
                  child: Text(
                    'Test date: ${formatDate(testDate)}',
                    style: const TextStyle(
                      color: Riso.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
        actions: [
          PopupMenuButton<void>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text('Signed in as ${couple.me.displayName}'),
              ),
              PopupMenuItem(
                onTap: widget.dependencies.auth.signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          CalendarPage(
            key: ValueKey('calendar-$_revision'),
            dependencies: widget.dependencies,
            couple: couple,
            onChanged: _onChanged,
          ),
          ComposePage(
            key: ValueKey('compose-$_revision'),
            dependencies: widget.dependencies,
            couple: couple,
          ),
          GalleryPage(
            key: ValueKey('gallery-$_revision'),
            dependencies: widget.dependencies,
            couple: couple,
            onChanged: _onChanged,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_view_month_outlined),
            selectedIcon: Icon(Icons.calendar_view_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_outlined),
            selectedIcon: Icon(Icons.edit),
            label: 'Prepare',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Gallery',
          ),
        ],
      ),
    );
  }
}
