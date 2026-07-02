---
name: flutter-bloc-repository-architecture
description: Use when starting a new Flutter project or feature that needs scalable state management and data access — sets up a feature-based BLoC/Cubit + Repository + GetIt layered architecture with in-memory fake repositories for development.
---

# Flutter BLoC + Repository + GetIt Architecture

## Contents
- [Architectural Layers](#architectural-layers)
- [Project Structure](#project-structure)
- [Required Packages](#required-packages)
- [Workflow: Implementing a New Feature](#workflow-implementing-a-new-feature)
- [BLoC vs Cubit — When to Use Which](#bloc-vs-cubit--when-to-use-which)
- [Examples](#examples)
- [Conventions & Gotchas](#conventions--gotchas)

## Architectural Layers

Enforce a strict separation between UI, state management, and data access. UI widgets never touch repositories or databases directly — they only read state and dispatch events/methods.

### UI Layer (Views)
Widgets are dumb. They render state from a BLoC/Cubit and dispatch events (`context.read<Bloc>().add(...)`) or call cubit methods. Store BLoCs as fields on `State` classes (not created inside `build`) so they survive rebuilds. Provide them via `BlocProvider.value` and read them via `BlocBuilder` / `context.read` / `context.watch`.

### Logic Layer (BLoCs / Cubits)
Manages presentation state and orchestrates repository calls. Every BLoC/Cubit takes its repositories through the constructor (no direct `getIt` calls inside handlers). Emits `Initial` → `Loading` → `Loaded` / `Error` states. Held by the DI container; created fresh per screen (`registerFactory`) or shared app-wide (`registerLazySingleton`).

### Data Layer (Repositories + Services)
- **Repository interfaces** live in `core/abstractions/repositories/` and define the contract.
- **Real implementations** live in `infrastructure/repositories/`, depend on a database/HTTP service + logger, and wrap every operation in try/catch that logs and throws a `RepositoryException`.
- **Fake implementations** live in `infrastructure/repositories/fake/`, hold data in memory with a `_nextId` counter, and simulate latency with `Future.delayed`. Used for local development and demos without a database.

## Project Structure

```text
lib/
├── app_settings.dart                    # Global compile-time flags (incl. useFakeRepositories)
├── main.dart
├── core/
│   ├── abstractions/
│   │   └── repositories/                # I<Name>Repository interfaces
│   ├── di/
│   │   └── injection_container.dart     # initializeDependencies() entry point
│   ├── enums/
│   ├── exceptions/                      # RepositoryException, etc.
│   ├── models/                          # Domain models (Equatable + fromMap/toMap/copyWith)
│   └── router/
├── features/
│   ├── blocs/
│   │   └── bloc_providers.dart          # registerBlocServices(getIt)
│   └── <feature_name>/                  # e.g. products/, orders/, profile/
│       ├── blocs/
│       │   └── <bloc_name>/
│       │       ├── <name>_bloc.dart
│       │       ├── <name>_event.dart
│       │       └── <name>_state.dart
│       │   OR
│       │   └── <cubit_name>/
│       │       ├── <name>_cubit.dart
│       │       └── <name>_state.dart    # optional; may live in cubit file for simple cubits
│       └── views/
│           ├── <screen>_screen.dart
│           └── widgets/
├── infrastructure/
│   ├── database/                        # sqflite helper + constants
│   ├── logging/                         # ILoggerService + impls
│   └── repositories/
│       ├── <name>_repository.dart       # real impls
│       ├── repository_providers.dart    # registerRepositoryServices(getIt)
│       └── fake/
│           ├── fake_<name>_repository.dart
│           └── fake_repository_providers.dart  # registerFakeRepositories(getIt)
└── shared/
    ├── app_theme.dart
    └── widgets/                         # Reusable design-system widgets
```

Group **UI** by feature (`features/<name>/`), group **data** by type (`infrastructure/repositories/`). Feature folders always contain `blocs/` + `views/` and may add `widgets/`, `dialogs/`, `utils/`, `models/`, or `constants/` as needed.

## Required Packages

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_bloc: ^9.1.1     # BLoC + Cubit + BlocProvider/BlocBuilder
  equatable: ^2.0.5        # Value equality for events and states
  get_it: ^9.2.0           # Dependency injection container
  sqflite: ^2.4.1          # (Optional) local database for real repositories
```

## Workflow: Implementing a New Feature

Copy this checklist and tick as you go.

### Task Progress
- [ ] **Step 1: Define the domain model.** Create an immutable class in `lib/core/models/<name>.dart`. Extend `Equatable`, add `fromMap` / `toMap` factories and a `copyWith` method.
- [ ] **Step 2: Add the repository interface.** In `lib/core/abstractions/repositories/i_<name>_repository.dart`, declare the CRUD operations. Create/update methods return the entity; delete returns `void`.
- [ ] **Step 3: Implement the real repository.** In `lib/infrastructure/repositories/<name>_repository.dart`, inject `IDatabaseService` + `ILoggerService`. Wrap every op in try/catch → log → throw `RepositoryException`.
- [ ] **Step 4: Implement the fake repository.** In `lib/infrastructure/repositories/fake/fake_<name>_repository.dart`, back the data with an in-memory `List<T>` seeded with sample data, an `int _nextId`, and `Future.delayed(...)` for realism.
- [ ] **Step 5: Register both.** Add the real impl to `registerRepositoryServices` and the fake to `registerFakeRepositories`. Both use `registerLazySingleton` (fakes need singleton so their in-memory list survives).
- [ ] **Step 6: Choose BLoC or Cubit.** Use BLoC when you need discrete, tracked events (loading, refresh, mutations, reordering). Use Cubit for simpler, per-widget state or when methods map 1-to-1 to UI actions.
- [ ] **Step 7: Create the BLoC/Cubit files** under `lib/features/<feature>/blocs/<name>/`. For BLoCs, split into `_bloc.dart` + `_event.dart` + `_state.dart`. For Cubits, one `_cubit.dart` (state can live in the same file or a sibling `_state.dart` if it grows).
- [ ] **Step 8: Register the BLoC/Cubit.** In `lib/features/blocs/bloc_providers.dart`, use `registerFactory` for per-screen instances, `registerLazySingleton` for app-wide state, and `registerFactoryParam` when the BLoC/Cubit needs runtime arguments (wrap them in a `Params` class).
- [ ] **Step 9: Wire up the screen.** Store the BLoC as `late final X _bloc` in the `State`; instantiate it via `getIt<X>()..add(const LoadEvent())` in `initState`; close it in `dispose`. Wrap the screen body with `BlocProvider.value(value: _bloc, child: BlocBuilder<X, XState>(...))`. Dispatch events via `context.read<X>().add(...)`.
- [ ] **Step 10: Toggle `AppSettings.useFakeRepositories`** when switching between development (fakes) and production (real database).

## BLoC vs Cubit — When to Use Which

| Use **BLoC** when… | Use **Cubit** when… |
|---|---|
| You have multiple discrete triggers (load, refresh, mutate, reorder) | State changes come from direct UI method calls |
| You want an auditable event history for debugging | The screen holds simple, localized state |
| Handlers benefit from `Emitter<State>` (streams, `emit.forEach`) | You'd otherwise create one event per method (verbose) |
| Multiple widgets dispatch the same action | Only one owner mutates the state |

Both extend `Equatable`. States always follow `Initial` / `Loading` / `Loaded` / `Error`. Screens read them the same way (`BlocBuilder`, `context.read`).

## Examples

The examples below use a generic `Product` entity. Substitute your own domain type when applying the pattern.

### 1. Domain model

Located at `lib/core/models/product.dart`. Immutable, value-equal, serialisable.

```dart
class Product extends Equatable {
  final int? id;
  final String name;
  final String description;
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
  });

  Product copyWith({int? id, String? name, String? description, double? price}) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  factory Product.fromMap(Map<String, dynamic> map) => Product(/* ... */);
  Map<String, dynamic> toMap() => {/* ... */};

  @override
  List<Object?> get props => [id, name, description, price, createdAt, updatedAt];
}
```

### 2. Repository interface

Located at `lib/core/abstractions/repositories/i_product_repository.dart`. Create/update return the entity; delete returns void.

```dart
abstract class IProductRepository {
  Future<List<Product>> getAll();
  Future<Product?> getById(int id);
  Future<Product> create(Product product);
  Future<Product> update(Product product);
  Future<void> delete(int id);
}
```

### 3. Real repository implementation

Located at `lib/infrastructure/repositories/product_repository.dart`. Every method: try → do work → catch → log → throw `RepositoryException`.

```dart
class ProductRepository implements IProductRepository {
  final IDatabaseService _databaseService;
  final ILoggerService _logger;
  ProductRepository(this._databaseService, this._logger);

  @override
  Future<List<Product>> getAll() async {
    try {
      final db = await _databaseService.database;
      final maps = await db.query(
        DatabaseConstants.tableProducts,
        orderBy: '${DatabaseConstants.columnCreatedAt} DESC',
      );
      return maps.map((map) => Product.fromMap(map)).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get all products', error: e, stackTrace: stackTrace);
      throw RepositoryException('Failed to retrieve products', e);
    }
  }

  @override
  Future<Product> create(Product product) async {
    try {
      final db = await _databaseService.database;
      final id = await db.insert(DatabaseConstants.tableProducts, product.toMap());
      return product.copyWith(id: id);
    } catch (e, stackTrace) {
      _logger.error('Failed to create product', error: e, stackTrace: stackTrace);
      throw RepositoryException('Failed to create product', e);
    }
  }
}
```

### 4. Fake repository implementation

Located at `lib/infrastructure/repositories/fake/fake_product_repository.dart`. In-memory list + `_nextId` + `Future.delayed`.

```dart
class FakeProductRepository implements IProductRepository {
  final List<Product> _items = [
    Product(id: 1, name: 'Sample A', description: '...', price: 9.99,
        createdAt: DateTime(2024, 1, 1), updatedAt: DateTime(2024, 1, 1)),
    Product(id: 2, name: 'Sample B', description: '...', price: 14.99,
        createdAt: DateTime(2024, 2, 1), updatedAt: DateTime(2024, 2, 1)),
  ];
  int _nextId = 3;

  @override
  Future<List<Product>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List<Product>.from(_items)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Product> create(Product product) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final created = product.copyWith(id: _nextId++);
    _items.add(created);
    return created;
  }
}
```

### 5. BLoC — events

Located at `lib/features/products/blocs/product_list/product_list_event.dart`. Abstract base extending `Equatable`; one class per event.

```dart
abstract class ProductListEvent extends Equatable {
  const ProductListEvent();
  @override
  List<Object?> get props => [];
}

class LoadProducts extends ProductListEvent {
  const LoadProducts();
}

class RefreshProducts extends ProductListEvent {
  const RefreshProducts();
}

class DeleteProduct extends ProductListEvent {
  final int productId;
  const DeleteProduct(this.productId);
  @override
  List<Object?> get props => [productId];
}
```

### 6. BLoC — states

Located at `lib/features/products/blocs/product_list/product_list_state.dart`. `Initial` / `Loading` / `Loaded` / `Error`. Include a `timestamp` field on `Loaded` so successive emits with identical data still trigger rebuilds.

```dart
abstract class ProductListState extends Equatable {
  const ProductListState();
  @override
  List<Object?> get props => [];
}

class ProductListInitial extends ProductListState { const ProductListInitial(); }
class ProductListLoading extends ProductListState { const ProductListLoading(); }

class ProductListLoaded extends ProductListState {
  final List<Product> products;
  final DateTime timestamp; // Forces uniqueness across emissions

  ProductListLoaded({
    required this.products,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  ProductListLoaded copyWith({List<Product>? products}) =>
      ProductListLoaded(products: products ?? this.products);

  @override
  List<Object?> get props => [products, timestamp];
}

class ProductListError extends ProductListState {
  final String message;
  const ProductListError(this.message);
  @override
  List<Object?> get props => [message];
}
```

### 7. BLoC — the bloc file

Located at `lib/features/products/blocs/product_list/product_list_bloc.dart`. Repositories injected via constructor; `on<Event>(handler)` for each event.

```dart
class ProductListBloc extends Bloc<ProductListEvent, ProductListState> {
  final IProductRepository _productRepository;

  ProductListBloc({
    required IProductRepository productRepository,
  })  : _productRepository = productRepository,
        super(const ProductListInitial()) {
    on<LoadProducts>(_onLoad);
    on<RefreshProducts>(_onRefresh);
    on<DeleteProduct>(_onDelete);
  }

  Future<void> _onLoad(LoadProducts event, Emitter<ProductListState> emit) async {
    emit(const ProductListLoading());
    try {
      final products = await _productRepository.getAll();
      emit(ProductListLoaded(products: products));
    } catch (e) {
      emit(ProductListError(e.toString()));
    }
  }

  // Optimistic update — emit immediately, revert on failure.
  Future<void> _onDelete(DeleteProduct event, Emitter<ProductListState> emit) async {
    final current = state;
    if (current is! ProductListLoaded) return;
    final without = current.products.where((p) => p.id != event.productId).toList();
    emit(current.copyWith(products: without));
    try {
      await _productRepository.delete(event.productId);
    } catch (_) {
      emit(current); // Revert
    }
  }
}
```

### 8. Cubit — mutation with repository

Located at `lib/features/products/blocs/product_detail/product_detail_cubit.dart`. No events — UI calls methods directly, cubit emits states inline.

```dart
class ProductDetailCubit extends Cubit<ProductDetailState> {
  final int productId;
  final IProductRepository _repository;

  ProductDetailCubit({
    required this.productId,
    required IProductRepository repository,
  })  : _repository = repository,
        super(const ProductDetailInitial()) {
    _load();
  }

  Future<void> _load() async {
    emit(const ProductDetailLoading());
    try {
      final product = await _repository.getById(productId);
      if (product == null) {
        emit(const ProductDetailError('Not found'));
        return;
      }
      emit(ProductDetailLoaded(product: product));
    } catch (e) {
      emit(ProductDetailError(e.toString()));
    }
  }

  Future<void> updatePrice(double newPrice) async {
    final current = state;
    if (current is! ProductDetailLoaded) return;
    try {
      final updated = await _repository.update(
        current.product.copyWith(price: newPrice),
      );
      emit(current.copyWith(product: updated));
    } catch (e) {
      emit(ProductDetailError('Failed to update: $e'));
    }
  }
}
```

A "pure view-model" cubit that holds no repository (e.g. card state) is equally valid — just expose the constructor and one or two `emit()` methods.

### 9. Dependency Injection — the container

Located at `lib/core/di/injection_container.dart`. One flag flips the whole app between fakes and real repositories.

```dart
final getIt = GetIt.instance;

Future<void> initializeDependencies() async {
  registerLoggingServices(getIt);
  registerServiceProviders(getIt);

  if (AppSettings.useFakeRepositories) {
    registerFakeRepositories(getIt);
  } else {
    registerDatabaseServices(getIt);
    registerRepositoryServices(getIt);
  }

  registerBlocServices(getIt);
  registerRouterProviders(getIt);
}
```

### 10. DI — BLoC providers

Located at `lib/features/blocs/bloc_providers.dart`. Three registration flavors cover almost all cases.

```dart
void registerBlocServices(GetIt getIt) {
  // App-wide, long-lived state: singleton
  getIt.registerLazySingleton<AppSettingsCubit>(
    () => AppSettingsCubit(getIt<IAppSettingsRepository>()),
  );

  // Feature BLoC: fresh instance per screen
  getIt.registerFactory<ProductListBloc>(
    () => ProductListBloc(
      productRepository: getIt<IProductRepository>(),
    ),
  );

  // Cubit that needs runtime arguments: registerFactoryParam + Params class
  getIt.registerFactoryParam<ProductDetailCubit, ProductDetailParams, void>(
    (params, _) => ProductDetailCubit(
      productId: params.productId,
      repository: getIt<IProductRepository>(),
    ),
  );
}

class ProductDetailParams {
  final int productId;
  const ProductDetailParams({required this.productId});
}
```

### 11. DI — repository providers (real vs fake)

Located at `lib/infrastructure/repositories/repository_providers.dart` and `.../fake/fake_repository_providers.dart`. Both use `registerLazySingleton` — fakes MUST be singletons so their in-memory state persists across lookups.

```dart
// Real
void registerRepositoryServices(GetIt getIt) {
  getIt.registerLazySingleton<IProductRepository>(
    () => ProductRepository(getIt(), getIt()),
  );
}

// Fake
void registerFakeRepositories(GetIt getIt) {
  getIt.registerLazySingleton<IProductRepository>(
    () => FakeProductRepository(),
  );
}
```

### 12. Screen — wiring the BLoC

Located at `lib/features/products/views/product_list_screen.dart`. Store the BLoC in the `State`, close it in `dispose`, provide via `BlocProvider.value`, dispatch via `context.read`.

```dart
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final ProductListBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ProductListBloc>()..add(const LoadProducts());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () async =>
              context.read<ProductListBloc>().add(const RefreshProducts()),
          child: BlocBuilder<ProductListBloc, ProductListState>(
            builder: (context, state) {
              if (state is ProductListLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is ProductListError) {
                return Center(child: Text(state.message));
              }
              if (state is ProductListLoaded) {
                return ListView.builder(
                  itemCount: state.products.length,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(state.products[i].name),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
```

### 13. The fake/real toggle

Located at `lib/app_settings.dart`. A single compile-time constant flips the whole app.

```dart
class AppSettings {
  AppSettings._();

  /// true  → in-memory fake repositories (fast dev, demos, screenshots)
  /// false → real database-backed repositories (production)
  static const bool useFakeRepositories = false;

  static const String databaseName = 'app.db';
  static const int databaseVersion = 1;
}
```

## Conventions & Gotchas

- **`Equatable` everywhere.** Every event and state extends `Equatable` and defines `props`. Same rule for domain models.
- **`timestamp` on `Loaded` states.** Include a `DateTime timestamp` (defaulted to `DateTime.now()`) so identical data emissions still trigger a rebuild.
- **Fakes are `LazySingleton`, not `Factory`.** If you register fakes as factories, each `getIt<X>()` builds a new list and in-memory state resets.
- **Repositories throw `RepositoryException`.** Every real repo op is wrapped in try → log → `throw RepositoryException(...)`. BLoCs catch these and emit an error state — never let a raw database exception reach the UI.
- **CRUD return values.** `create` and `update` return the entity (with server-assigned ID + timestamps). `delete` returns `void`. Interfaces enforce this.
- **BLoC lifecycle.** Store the BLoC as `late final X _bloc` in the `State`. Instantiate in `initState`, close in `dispose`. Never create it inside `build`.
- **`BlocProvider.value` for existing BLoCs.** Use `BlocProvider.value` when providing a BLoC you already own; use `BlocProvider(create: ...)` only when the provider itself should own creation.
- **`context.read` vs `context.watch` vs `BlocBuilder`.** `read` for one-shot dispatch (button taps, `onRefresh`). `BlocBuilder` for the widget subtree that needs to rebuild on state change. `watch` inside `build` for finer-grained rebuilds.
- **Registration flavors.** `registerLazySingleton` for app-wide state, `registerFactory` for per-screen BLoCs, `registerFactoryParam` + a `Params` class for cubits with runtime arguments.
- **Feature isolation.** Each feature folder owns its `blocs/` and `views/`. Cross-feature dependencies go through repository interfaces, never through another feature's BLoC.
- **One flag to rule the data layer.** Flipping `AppSettings.useFakeRepositories` swaps every repository in the app — never conditionally import fakes anywhere else.
