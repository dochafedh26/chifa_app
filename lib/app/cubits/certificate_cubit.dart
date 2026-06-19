import "package:chifa/services/db/repositories/repositories.dart";
import "package:chifa/services/db/models/models.dart";
import "package:dartz/dartz.dart";
import "package:equatable/equatable.dart";
import "package:flutter_bloc/flutter_bloc.dart";

// Certificate Events
abstract class CertificateEvent extends Equatable {
  const CertificateEvent();

  @override
  List<Object?> get props => [];
}

// Arret de travail events
class LoadArretsDeTravail extends CertificateEvent {}

class LoadArretDeTravailById extends CertificateEvent {
  final int id;

  const LoadArretDeTravailById(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadArretsDeTravailByPatientId extends CertificateEvent {
  final int patientId;

  const LoadArretsDeTravailByPatientId(this.patientId);

  @override
  List<Object?> get props => [patientId];
}

class LoadArretsDeTravailByDoctorId extends CertificateEvent {
  final int doctorId;

  const LoadArretsDeTravailByDoctorId(this.doctorId);

  @override
  List<Object?> get props => [doctorId];
}

class LoadArretsDeTravailByType extends CertificateEvent {
  final String type;

  const LoadArretsDeTravailByType(this.type);

  @override
  List<Object?> get props => [type];
}

class SearchArretsDeTravail extends CertificateEvent {
  final String query;

  const SearchArretsDeTravail(this.query);

  @override
  List<Object?> get props => [query];
}

class CreateArretDeTravail extends CertificateEvent {
  final ArretDeTravail arretDeTravail;

  const CreateArretDeTravail(this.arretDeTravail);

  @override
  List<Object?> get props => [arretDeTravail];
}

class UpdateArretDeTravail extends CertificateEvent {
  final int id;
  final ArretDeTravail arretDeTravail;

  const UpdateArretDeTravail(this.id, this.arretDeTravail);

  @override
  List<Object?> get props => [id, arretDeTravail];
}

class DeleteArretDeTravail extends CertificateEvent {
  final int id;

  const DeleteArretDeTravail(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadArretsDeTravailByDateRange extends CertificateEvent {
  final DateTime startDate;
  final DateTime endDate;

  const LoadArretsDeTravailByDateRange(this.startDate, this.endDate);

  @override
  List<Object?> get props => [startDate, endDate];
}

// Lettre events
class LoadLettres extends CertificateEvent {}

class LoadLettreById extends CertificateEvent {
  final int id;

  const LoadLettreById(this.id);

  @override
  List<Object?> get props => [id];
}

class LoadLettresByPatientId extends CertificateEvent {
  final int patientId;

  const LoadLettresByPatientId(this.patientId);

  @override
  List<Object?> get props => [patientId];
}

class LoadLettresByDoctorId extends CertificateEvent {
  final int doctorId;

  const LoadLettresByDoctorId(this.doctorId);

  @override
  List<Object?> get props => [doctorId];
}

class SearchLettres extends CertificateEvent {
  final String query;

  const SearchLettres(this.query);

  @override
  List<Object?> get props => [query];
}

class CreateLettre extends CertificateEvent {
  final Lettre lettre;

  const CreateLettre(this.lettre);

  @override
  List<Object?> get props => [lettre];
}

class UpdateLettre extends CertificateEvent {
  final int id;
  final Lettre lettre;

  const UpdateLettre(this.id, this.lettre);

  @override
  List<Object?> get props => [id, lettre];
}

class DeleteLettre extends CertificateEvent {
  final int id;

  const DeleteLettre(this.id);

  @override
  List<Object?> get props => [id];
}

// Certificate States
abstract class CertificateState extends Equatable {
  const CertificateState();

  @override
  List<Object?> get props => [];
}

class CertificateInitial extends CertificateState {}

class CertificateLoading extends CertificateState {}

class ArretsDeTravailLoaded extends CertificateState {
  final List<ArretDeTravail> arretsDeTravail;

  const ArretsDeTravailLoaded(this.arretsDeTravail);

  @override
  List<Object?> get props => [arretsDeTravail];
}

class ArretDeTravailLoaded extends CertificateState {
  final ArretDeTravail arretDeTravail;

  const ArretDeTravailLoaded(this.arretDeTravail);

  @override
  List<Object?> get props => [arretDeTravail];
}

class LettresLoaded extends CertificateState {
  final List<Lettre> lettres;

  const LettresLoaded(this.lettres);

  @override
  List<Object?> get props => [lettres];
}

class LettreLoaded extends CertificateState {
  final Lettre lettre;

  const LettreLoaded(this.lettre);

  @override
  List<Object?> get props => [lettre];
}

class CertificatsMaladieChroniqueLoaded extends CertificateState {
  final List<CertificatMaladieChronique> certificats;
  const CertificatsMaladieChroniqueLoaded(this.certificats);
  @override
  List<Object?> get props => [certificats];
}

class CertificatsBonneSanteLoaded extends CertificateState {
  final List<CertificatBonneSante> certificats;
  const CertificatsBonneSanteLoaded(this.certificats);
  @override
  List<Object?> get props => [certificats];
}

class CertificatsDispenseSportLoaded extends CertificateState {
  final List<CertificatDispenseSport> certificats;
  const CertificatsDispenseSportLoaded(this.certificats);
  @override
  List<Object?> get props => [certificats];
}

class CertificatsPrenuptialLoaded extends CertificateState {
  final List<CertificatPrenuptial> certificats;
  const CertificatsPrenuptialLoaded(this.certificats);
  @override
  List<Object?> get props => [certificats];
}

class CertificateError extends CertificateState {
  final String message;

  const CertificateError(this.message);

  @override
  List<Object?> get props => [message];
}

class CertificateOperationSuccess extends CertificateState {
  final String message;

  const CertificateOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Certificate Cubit
class CertificateCubit extends Cubit<CertificateState> {
  final ArretDeTravailRepository _arretRepository;
  final LettreRepository _lettreRepository;
  final CertificatMaladieChroniqueRepository _maladieChroniqueRepository;
  final CertificatBonneSanteRepository _bonneSanteRepository;
  final CertificatDispenseSportRepository _dispenseSportRepository;
  final CertificatPrenuptialRepository _prenuptialRepository;

  List<CertificatMaladieChronique> allCertificatsMaladieChronique = [];
  List<CertificatBonneSante> allCertificatsBonneSante = [];
  List<CertificatDispenseSport> allCertificatsDispenseSport = [];
  List<CertificatPrenuptial> allCertificatsPrenuptial = [];

  List<ArretDeTravail> _allArrets = [];
  List<Lettre> _allLettres = [];

  List<ArretDeTravail> get allArrets => _allArrets;
  List<Lettre> get allLettres => _allLettres;

  CertificateCubit(
    this._arretRepository,
    this._lettreRepository,
    this._maladieChroniqueRepository,
    this._bonneSanteRepository,
    this._dispenseSportRepository,
    this._prenuptialRepository,
  ) : super(CertificateInitial());

  // ==================== ARRET DE TRAVAIL ====================

  /// Load all arrets de travail
  Future<void> loadArretsDeTravail() async {
    emit(CertificateLoading());

    final result = await _arretRepository.getAll();

    result.fold((failure) => emit(CertificateError(failure.message)), (arrets) {
      _allArrets = arrets;
      emit(ArretsDeTravailLoaded(arrets));
    });
  }

  /// Load arret de travail by ID
  Future<void> loadArretDeTravailById(int id) async {
    emit(CertificateLoading());

    final result = await _arretRepository.getById(id);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (arret) => emit(ArretDeTravailLoaded(arret)),
    );
  }

  /// Load arrets de travail by patient ID
  Future<void> loadArretsDeTravailByPatientId(int patientId) async {
    emit(CertificateLoading());

    final result = await _arretRepository.getByPatientId(patientId);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (arrets) => emit(ArretsDeTravailLoaded(arrets)),
    );
  }

  /// Load arrets de travail by doctor ID
  Future<void> loadArretsDeTravailByDoctorId(int doctorId) async {
    emit(CertificateLoading());

    final result = await _arretRepository.getByDoctorId(doctorId);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (arrets) => emit(ArretsDeTravailLoaded(arrets)),
    );
  }

  /// Load arrets de travail by type
  Future<void> loadArretsDeTravailByType(String type) async {
    emit(CertificateLoading());

    final result = await _arretRepository.getByType(type);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (arrets) => emit(ArretsDeTravailLoaded(arrets)),
    );
  }

  /// Search arrets de travail
  Future<void> searchArretsDeTravail(String query) async {
    if (query.isEmpty) {
      emit(ArretsDeTravailLoaded(_allArrets));
      return;
    }

    emit(CertificateLoading());

    final result = await _arretRepository.search(query);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (arrets) => emit(ArretsDeTravailLoaded(arrets)),
    );
  }

  /// Create new arret de travail
  Future<void> createArretDeTravail(ArretDeTravail arretDeTravail) async {
    final result = await _arretRepository.create(arretDeTravail);

    result.fold((failure) => emit(CertificateError(failure.message)), (id) {
      emit(
        const CertificateOperationSuccess(
          'Work certificate created successfully',
        ),
      );
      loadArretsDeTravail();
    });
  }

  /// Update arret de travail
  Future<void> updateArretDeTravail(
    int id,
    ArretDeTravail arretDeTravail,
  ) async {
    final result = await _arretRepository.update(id, arretDeTravail);

    result.fold((failure) => emit(CertificateError(failure.message)), (
      success,
    ) {
      if (success) {
        emit(
          const CertificateOperationSuccess(
            'Work certificate updated successfully',
          ),
        );
        loadArretsDeTravail();
      } else {
        emit(const CertificateError('Failed to update work certificate'));
      }
    });
  }

  /// Delete arret de travail
  Future<void> deleteArretDeTravail(int id) async {
    final result = await _arretRepository.delete(id);

    result.fold((failure) => emit(CertificateError(failure.message)), (
      success,
    ) {
      if (success) {
        emit(
          const CertificateOperationSuccess(
            'Work certificate deleted successfully',
          ),
        );
        loadArretsDeTravail();
      } else {
        emit(const CertificateError('Failed to delete work certificate'));
      }
    });
  }

  /// Load arrets de travail by date range
  Future<void> loadArretsDeTravailByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    emit(CertificateLoading());

    final result = await _arretRepository.getByDateRange(startDate, endDate);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (arrets) => emit(ArretsDeTravailLoaded(arrets)),
    );
  }

  /// Get arrets de travail count
  Future<int> getArretsDeTravailCount() async {
    final result = await _arretRepository.getCount();
    return result.fold((_) => 0, (count) => count);
  }

  // ==================== LETTRE ====================

  /// Load all lettres
  Future<void> loadLettres() async {
    emit(CertificateLoading());

    final result = await _lettreRepository.getAll();

    result.fold((failure) => emit(CertificateError(failure.message)), (
      lettres,
    ) {
      _allLettres = lettres;
      emit(LettresLoaded(lettres));
    });
  }

  /// Load lettre by ID
  Future<void> loadLettreById(int id) async {
    emit(CertificateLoading());

    final result = await _lettreRepository.getById(id);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (lettre) => emit(LettreLoaded(lettre)),
    );
  }

  /// Load lettres by patient ID
  Future<void> loadLettresByPatientId(int patientId) async {
    emit(CertificateLoading());

    final result = await _lettreRepository.getByPatientId(patientId);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (lettres) => emit(LettresLoaded(lettres)),
    );
  }

  /// Load lettres by doctor ID
  Future<void> loadLettresByDoctorId(int doctorId) async {
    emit(CertificateLoading());

    final result = await _lettreRepository.getByDoctorId(doctorId);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (lettres) => emit(LettresLoaded(lettres)),
    );
  }

  /// Search lettres
  Future<void> searchLettres(String query) async {
    if (query.isEmpty) {
      emit(LettresLoaded(_allLettres));
      return;
    }

    emit(CertificateLoading());

    final result = await _lettreRepository.search(query);

    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (lettres) => emit(LettresLoaded(lettres)),
    );
  }

  /// Create new lettre
  Future<void> createLettre(Lettre lettre) async {
    final result = await _lettreRepository.create(lettre);

    result.fold((failure) => emit(CertificateError(failure.message)), (id) {
      emit(
        const CertificateOperationSuccess(
          'Medical letter created successfully',
        ),
      );
      loadLettres();
    });
  }

  /// Update lettre
  Future<void> updateLettre(int id, Lettre lettre) async {
    final result = await _lettreRepository.update(id, lettre);

    result.fold((failure) => emit(CertificateError(failure.message)), (
      success,
    ) {
      if (success) {
        emit(
          const CertificateOperationSuccess(
            'Medical letter updated successfully',
          ),
        );
        loadLettres();
      } else {
        emit(const CertificateError('Failed to update medical letter'));
      }
    });
  }

  /// Delete lettre
  Future<void> deleteLettre(int id) async {
    final result = await _lettreRepository.delete(id);

    result.fold((failure) => emit(CertificateError(failure.message)), (
      success,
    ) {
      if (success) {
        emit(
          const CertificateOperationSuccess(
            'Medical letter deleted successfully',
          ),
        );
        loadLettres();
      } else {
        emit(const CertificateError('Failed to delete medical letter'));
      }
    });
  }

  /// Get latest lettre for a patient
  Future<void> getLatestLettreByPatientId(int patientId) async {
    emit(CertificateLoading());

    final result = await _lettreRepository.getLatestByPatientId(patientId);

    result.fold((failure) => emit(CertificateError(failure.message)), (lettre) {
      if (lettre != null) {
        emit(LettreLoaded(lettre));
      } else {
        emit(
          const CertificateError('No medical letters found for this patient'),
        );
      }
    });
  }

  /// Get lettres count
  Future<int> getLettresCount() async {
    final result = await _lettreRepository.getCount();
    return result.fold((_) => 0, (count) => count);
  }

  // ==================== MALADIE CHRONIQUE ====================

  Future<void> loadCertificatsMaladieChronique() async {
    emit(CertificateLoading());
    final certs = await _maladieChroniqueRepository.getAll();
    allCertificatsMaladieChronique = certs;
    emit(CertificatsMaladieChroniqueLoaded(certs));
  }

  Future<void> createCertificatMaladieChronique(CertificatMaladieChronique cert) async {
    final result = await _maladieChroniqueRepository.create(cert);
    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (id) {
        emit(const CertificateOperationSuccess('Chronic disease certificate created'));
        loadCertificatsMaladieChronique();
      },
    );
  }

  Future<void> deleteCertificatMaladieChronique(int id) async {
    final result = await _maladieChroniqueRepository.delete(id);
    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (success) {
        emit(const CertificateOperationSuccess('Chronic disease certificate deleted'));
        loadCertificatsMaladieChronique();
      },
    );
  }

  // ==================== BONNE SANTE ====================

  Future<void> loadCertificatsBonneSante() async {
    emit(CertificateLoading());
    final certs = await _bonneSanteRepository.getAll();
    allCertificatsBonneSante = certs;
    emit(CertificatsBonneSanteLoaded(certs));
  }

  Future<void> createCertificatBonneSante(CertificatBonneSante cert) async {
    final result = await _bonneSanteRepository.create(cert);
    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (id) {
        emit(const CertificateOperationSuccess('Good health certificate created'));
        loadCertificatsBonneSante();
      },
    );
  }

  Future<void> deleteCertificatBonneSante(int id) async {
    final result = await _bonneSanteRepository.delete(id);
    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (success) {
        emit(const CertificateOperationSuccess('Good health certificate deleted'));
        loadCertificatsBonneSante();
      },
    );
  }

  // ==================== DISPENSE SPORT ====================

  Future<void> loadCertificatsDispenseSport() async {
    emit(CertificateLoading());
    final certs = await _dispenseSportRepository.getAll();
    allCertificatsDispenseSport = certs;
    emit(CertificatsDispenseSportLoaded(certs));
  }

  Future<void> createCertificatDispenseSport(CertificatDispenseSport cert) async {
    final result = await _dispenseSportRepository.create(cert);
    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (id) {
        emit(const CertificateOperationSuccess('Sport exemption certificate created'));
        loadCertificatsDispenseSport();
      },
    );
  }

  Future<void> deleteCertificatDispenseSport(int id) async {
    final result = await _dispenseSportRepository.delete(id);
    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (success) {
        emit(const CertificateOperationSuccess('Sport exemption certificate deleted'));
        loadCertificatsDispenseSport();
      },
    );
  }

  // ==================== PRENUPTIAL ====================

  Future<void> loadCertificatsPrenuptial() async {
    emit(CertificateLoading());
    final certs = await _prenuptialRepository.getAll();
    allCertificatsPrenuptial = certs;
    emit(CertificatsPrenuptialLoaded(certs));
  }

  Future<void> createCertificatPrenuptial(CertificatPrenuptial cert) async {
    final result = await _prenuptialRepository.create(cert);
    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (id) {
        emit(const CertificateOperationSuccess('Prenuptial certificate created'));
        loadCertificatsPrenuptial();
      },
    );
  }

  Future<void> deleteCertificatPrenuptial(int id) async {
    final result = await _prenuptialRepository.delete(id);
    result.fold(
      (failure) => emit(CertificateError(failure.message)),
      (success) {
        emit(const CertificateOperationSuccess('Prenuptial certificate deleted'));
        loadCertificatsPrenuptial();
      },
    );
  }
}
