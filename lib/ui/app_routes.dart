import 'package:flutter/widgets.dart';

/// Permet aux écrans de savoir quand on revient sur eux (ex. rafraîchir
/// « Continuer à regarder » après une lecture).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
