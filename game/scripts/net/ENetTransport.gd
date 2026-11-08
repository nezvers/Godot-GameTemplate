## Direct IP over ENet. The host is reached at ip:port; behind a router that needs
## a forwarded UDP port, which open_port() tries to map with UPnP.
class_name ENetTransport
extends NetTransport

## Channels: 0 reliable control/RPC, 1 unreliable snapshots, 2 link probes (NetStats).
const CHANNELS:int = 3
## ENet's defaults (ENET_PEER_PACKET_THROTTLE_INTERVAL / _SCALE).
const THROTTLE_INTERVAL_MS:int = 5000
const THROTTLE_SCALE:int = 32

var _upnp:UPNP
var _mapped_port:int = -1

func create_host(port:int, max_clients:int)->MultiplayerPeer:
	var _peer:ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	if _peer.create_server(port, max_clients, CHANNELS) != OK:
		return null
	return _peer

func create_client(address:String, port:int)->MultiplayerPeer:
	var _peer:ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	if _peer.create_client(address, port, CHANNELS) != OK:
		return null
	return _peer

## LAN addresses, plus the router's public address when UPnP mapping works.
## Blocking (UPnP discovery takes seconds): run it on a thread.
func share_addresses(port:int)->Array:
	var _list:Array = []
	var _public:String = _open_port(port)
	if !_public.is_empty():
		_list.append({"label": "Over the internet", "address": "%s:%d" % [_public, port]})
	for _ip:String in lan_addresses():
		_list.append({"label": "Same network", "address": "%s:%d" % [_ip, port]})
	_list.append({"label": "Same computer", "address": "127.0.0.1:%d" % port})
	return _list

## IPv4 addresses of real network cards: loopback, link-local and virtual
## interfaces (Docker, VMs, VPN tunnels) are left out, a friend can't reach those.
static func lan_addresses()->PackedStringArray:
	var _list:PackedStringArray = []
	for _interface:Dictionary in IP.get_local_interfaces():
		var _name:String = str(_interface.get("name", "")).to_lower()
		if _is_virtual(_name):
			continue
		for _ip:String in _interface.get("addresses", []):
			if _ip.contains(":") || _ip.begins_with("127.") || _ip.begins_with("169.254."):
				continue
			if !_list.has(_ip):
				_list.append(_ip)
	return _list

const VIRTUAL_PREFIXES:PackedStringArray = ["lo", "docker", "br-", "veth", "virbr", "vmnet", "vboxnet", "tun", "tap", "wg", "tailscale", "zt", "cni", "flannel", "podman", "lxc", "lxd", "vethernet"]

static func _is_virtual(interface_name:String)->bool:
	for _prefix:String in VIRTUAL_PREFIXES:
		if interface_name.begins_with(_prefix):
			return true
	return false

func _open_port(port:int)->String:
	_upnp = UPNP.new()
	if _upnp.discover(2000, 2) != UPNP.UPNP_RESULT_SUCCESS:
		return ""
	var _gateway:UPNPDevice = _upnp.get_gateway()
	if _gateway == null || !_gateway.is_valid_gateway():
		return ""
	if _upnp.add_port_mapping(port, port, "ZombieShooter co-op", "UDP") != UPNP.UPNP_RESULT_SUCCESS:
		return ""
	_mapped_port = port
	return _upnp.query_external_address()

## ENet's packet throttle drops unreliable packets (snapshots, probes) at random
## once it decides the link is congested, and it decides that from round trip
## swings frame timing alone causes. Our traffic is small and steady: send it all.
func tune_peer(peer:MultiplayerPeer, peer_id:int)->void:
	if !(peer is ENetMultiplayerPeer):
		return
	var _packet:ENetPacketPeer = (peer as ENetMultiplayerPeer).get_peer(peer_id)
	if _packet != null:
		# full throttle from the start and never slowed down
		_packet.throttle_configure(THROTTLE_INTERVAL_MS, THROTTLE_SCALE, 0)

func close()->void:
	if _upnp != null && _mapped_port > 0:
		_upnp.delete_port_mapping(_mapped_port, "UDP")
	_mapped_port = -1
