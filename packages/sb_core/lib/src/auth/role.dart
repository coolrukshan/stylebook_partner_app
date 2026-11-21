/// Salon partner user roles.
enum Role {
  owner,
  manager,
  specialist;

  /// Parses a string representation into a [Role], returning `null` if unrecognized.
  static Role? parse(String? value) {
    if (value == null) return null;
    return switch (value.trim().toLowerCase()) {
      'owner' => Role.owner,
      'manager' => Role.manager,
      'specialist' => Role.specialist,
      _ => null,
    };
  }
}
