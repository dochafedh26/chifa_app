
/// Represents a single prescription item (medicament + posology + duration)
class PrescriptionItem {
  final String name;
  final String dci;
  final String posology;
  final String duration;

  PrescriptionItem({
    required this.name,
    required this.dci,
    required this.posology,
    this.duration = '',
  });
}